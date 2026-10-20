/// AI 超分：Real-ESRGAN-General-x4v3（TFLite）分块推理。
///
/// 用法（主 isolate）：
/// 1. [loadAiModelBuffer] 经 rootBundle 取模型字节（平台通道，仅主 isolate 可用）；
/// 2. 把像素与模型字节交给 compute（[aiSuperResInBackground]）跑后台 isolate；
/// 3. 后台 isolate 内建解释器（优先 GPU 代理，失败降级 CPU 4 线程），
///    按 128×128 块 / 100 有效区 / 14 重叠切块推理，裁剪拼接成整图。
///
/// 策略：模型倍率 ×4，输入先 ÷2（Lanczos）得到净 2× 输出——阅读场景 2× 足够，
/// 块数（≈宽/100×高/100）比直接喂原图少 4 倍，速度与内存都可控。
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'image_ops.dart';

/// 模型资产路径。
const String kAiModelAsset = 'assets/models/realesrgan-general-x4v3.tflite';

/// 模型输入块边长（该导出版固定 128）。
const int kAiTileSize = 128;

/// 每块有效区边长：只信任中心 100×100，边缘 14 像素重叠区防接缝。
const int kAiEffective = 100;

/// 块重叠 padding。
const int kAiPadding = (kAiTileSize - kAiEffective) ~/ 2;

/// 块步进 = 有效区。
const int kAiStride = kAiEffective;

/// 模型倍率（×4）。
const int kAiScale = 4;

/// 输出像素封顶（约 8M，防低端机 OOM）。
const int kAiMaxOutputPixels = 8000000;

/// 输入预缩放下限（净倍率 = 4 × pre，pre 最小 0.25 → 净 1×）。
const double kAiMinPreScale = 0.25;

/// AI 推理结果。
class AiResult {
  const AiResult(this.pixels, this.width, this.height);

  final Uint8List pixels;
  final int width;
  final int height;
}

/// 取模型字节（主 isolate 调用；rootBundle 是平台通道）。
Future<Uint8List> loadAiModelBuffer() async {
  final data = await rootBundle.load(kAiModelAsset);
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

/// compute 入口（要求顶层函数）。
Future<AiResult> aiSuperResInBackground((
  {Uint8List modelBuffer,
  Uint8List pixels,
  int width,
  int height}
) msg) => _runAi(msg.modelBuffer, msg.pixels, msg.width, msg.height);
/// 计算输入预缩放系数：净 2×（pre=0.5）；小图不缩（净 4×）；输出超封顶则逐级降。
double _preScaleFor(int w, int h) {
  var pre = math.min(w, h) >= 2 * kAiEffective ? 0.5 : 1.0;
  while (pre > kAiMinPreScale && _outputPixels(w, h, pre) > kAiMaxOutputPixels) {
    pre -= 0.0625;
  }
  return pre;
}

int _outputPixels(int w, int h, double pre) {
  final ow = (w * pre).round() * kAiScale;
  final oh = (h * pre).round() * kAiScale;
  return ow * oh;
}

Future<AiResult> _runAi(Uint8List modelBuffer, Uint8List src, int sw, int sh) async {
  final pre = _preScaleFor(sw, sh);
  var px = src;
  var inW = sw;
  var inH = sh;
  if (pre < 1.0) {
    inW = (sw * pre).round();
    inH = (sh * pre).round();
    px = lanczosResizeRgba(src, sw, sh, inW, inH);
  }

  final outW = inW * kAiScale;
  final outH = inH * kAiScale;
  final out = Uint8List(outW * outH * 4);
  final outTile = kAiTileSize * kAiScale; // 512
  final outEffective = kAiEffective * kAiScale; // 400
  final outPad = kAiPadding * kAiScale; // 56

  Interpreter? interpreter;
  GpuDelegateV2? gpuDelegate;
  try {
    // GPU 优先（OpenGL），失败降级 CPU 4 线程。
    try {
      gpuDelegate = GpuDelegateV2(
        options: GpuDelegateOptionsV2(isPrecisionLossAllowed: true),
      );
      interpreter = Interpreter.fromBuffer(
        modelBuffer,
        options: InterpreterOptions()..addDelegate(gpuDelegate),
      );
    } catch (_) {
      gpuDelegate = null;
      interpreter = Interpreter.fromBuffer(
        modelBuffer,
        options: InterpreterOptions()..threads = 4,
      );
    }

    // 布局探测：NCHW([1,3,H,W]) vs NHWC([1,H,W,3])、float vs uint8。
    final inputShape = interpreter.getInputTensors()[0].shape;
    final inputNchw = inputShape.length >= 2 && inputShape[1] == 3;
    final inputQuantized = interpreter.getInputTensors()[0].type == TensorType.uint8;
    interpreter.resizeInputTensor(
      0,
      inputNchw
          ? [1, 3, kAiTileSize, kAiTileSize]
          : [1, kAiTileSize, kAiTileSize, 3],
    );
    interpreter.allocateTensors();

    final outputShape = interpreter.getOutputTensors()[0].shape;
    final outputNchw = outputShape.length >= 2 && outputShape[1] == 3;
    final outputQuantized = interpreter.getOutputTensors()[0].type == TensorType.uint8;

    final planeIn = kAiTileSize * kAiTileSize;
    final planeOut = outTile * outTile;
    final inputBuffer = inputQuantized
        ? Uint8List(planeIn * 3).buffer
        : Float32List(planeIn * 3).buffer;
    final outputBuffer = outputQuantized
        ? Uint8List(planeOut * 3).buffer
        : Float32List(planeOut * 3).buffer;

    for (var y = 0; y < inH; y += kAiStride) {
      for (var x = 0; x < inW; x += kAiStride) {
        _fillInput(px, inW, inH, x, y, inputBuffer, inputNchw, inputQuantized);
        interpreter.run(inputBuffer, outputBuffer);
        _stitchTile(
          out,
          outW,
          outH,
          x,
          y,
          outputBuffer,
          outTile,
          outEffective,
          outPad,
          outputNchw,
          outputQuantized,
        );
      }
    }
  } finally {
    interpreter?.close();
    gpuDelegate?.delete();
  }
  return AiResult(out, outW, outH);
}

/// 填一块输入（源坐标边缘钳位；支持 float/uint8 × NCHW/NHWC）。
///
/// 分支内各取一份非空视图（ByteBuffer 视图为零拷贝），规避可空局部的流分析歧义。
void _fillInput(
  Uint8List px,
  int inW,
  int inH,
  int startX,
  int startY,
  ByteBuffer buffer,
  bool nchw,
  bool quantized,
) {
  final plane = kAiTileSize * kAiTileSize;
  final bytes = buffer.asUint8List();
  final floats = buffer.asFloat32List();
  for (var ty = 0; ty < kAiTileSize; ty++) {
    final sy = (startY - kAiPadding + ty).clamp(0, inH - 1);
    for (var tx = 0; tx < kAiTileSize; tx++) {
      final sx = (startX - kAiPadding + tx).clamp(0, inW - 1);
      final i = (sy * inW + sx) * 4;
      final index = ty * kAiTileSize + tx;
      if (quantized) {
        if (nchw) {
          bytes[index] = px[i];
          bytes[plane + index] = px[i + 1];
          bytes[2 * plane + index] = px[i + 2];
        } else {
          final p = index * 3;
          bytes[p] = px[i];
          bytes[p + 1] = px[i + 1];
          bytes[p + 2] = px[i + 2];
        }
      } else {
        final r = px[i] / 255.0;
        final g = px[i + 1] / 255.0;
        final b = px[i + 2] / 255.0;
        if (nchw) {
          floats[index] = r;
          floats[plane + index] = g;
          floats[2 * plane + index] = b;
        } else {
          final p = index * 3;
          floats[p] = r;
          floats[p + 1] = g;
          floats[p + 2] = b;
        }
      }
    }
  }
}

/// 把输出块的有效区（去重叠边）裁拼进整图。
void _stitchTile(
  Uint8List out,
  int outW,
  int outH,
  int startX,
  int startY,
  ByteBuffer buffer,
  int outTile,
  int outEffective,
  int outPad,
  bool nchw,
  bool quantized,
) {
  final plane = outTile * outTile;
  // 两份非空视图（零拷贝），按输出类型二选一读取。
  final bytes = buffer.asUint8List();
  final floats = buffer.asFloat32List();
  for (var oy = 0; oy < outEffective; oy++) {
    final dstY = startY * kAiScale + oy;
    if (dstY >= outH) break;
    for (var ox = 0; ox < outEffective; ox++) {
      final dstX = startX * kAiScale + ox;
      if (dstX >= outW) break;
      final tileIndex = (oy + outPad) * outTile + (ox + outPad);
      double r;
      double g;
      double b;
      if (quantized) {
        if (nchw) {
          r = bytes[tileIndex] / 255.0;
          g = bytes[plane + tileIndex] / 255.0;
          b = bytes[2 * plane + tileIndex] / 255.0;
        } else {
          final p = tileIndex * 3;
          r = bytes[p] / 255.0;
          g = bytes[p + 1] / 255.0;
          b = bytes[p + 2] / 255.0;
        }
      } else {
        if (nchw) {
          r = floats[tileIndex];
          g = floats[plane + tileIndex];
          b = floats[2 * plane + tileIndex];
        } else {
          final p = tileIndex * 3;
          r = floats[p];
          g = floats[p + 1];
          b = floats[p + 2];
        }
      }
      final di = (dstY * outW + dstX) * 4;
      out[di] = (r * 255).clamp(0, 255).round();
      out[di + 1] = (g * 255).clamp(0, 255).round();
      out[di + 2] = (b * 255).clamp(0, 255).round();
      out[di + 3] = 255;
    }
  }
}

/// 供测试/预览：把 RGBA 字节包成 [ui.Image]（主 isolate）。
Future<ui.Image> pixelsToImage(Uint8List pixels, int width, int height) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(pixels, width, height, ui.PixelFormat.rgba8888, completer.complete);
  return completer.future;
}
