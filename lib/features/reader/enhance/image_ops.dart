/// 画质增强像素运算库：RGBA8888 直排（非预乘）、行优先的纯 Dart 实现。
///
/// 全部为同步纯函数（无 IO、无 Flutter 依赖），可整体跑在后台 isolate：
/// - [boxBlurRgba] 可分离盒式模糊（滑窗 O(1)/像素），多次≈高斯；
/// - [unsharpMaskRgba] USM 锐化 / 清晰度（大半径低分量即局部对比度）；
/// - [adjustContrastRgba] 全局对比度；
/// - [lanczosResizeRgba] Lanczos-3 重采样（超级分辨率放大部分）。
library;

import 'dart:math' as math;
import 'dart:typed_data';

/// 可分离盒式模糊。[radius] 为盒半径（像素），[passes] 次盒式≈高斯（σ≈radius）。
///
/// 原地修改 [px]：内部双缓冲，[tmp] 尺寸与 [px] 相同。
void boxBlurRgba(Uint8List px, int w, int h, int radius, {int passes = 2}) {
  if (radius < 1 || w <= 0 || h <= 0 || px.length < w * h * 4) return;
  final tmp = Uint8List(px.length);
  for (var p = 0; p < passes; p++) {
    _boxBlurPass(px, tmp, w, h, radius, horizontal: true);
    _boxBlurPass(tmp, px, w, h, radius, horizontal: false);
  }
}

/// 单次单方向盒式模糊（滑窗累加，边界钳位）。
void _boxBlurPass(
  Uint8List src,
  Uint8List dst,
  int w,
  int h,
  int radius, {
  required bool horizontal,
}) {
  final outer = horizontal ? h : w; // 行数
  final inner = horizontal ? w : h; // 每行像素数
  if (inner <= 0 || outer <= 0) return;
  final pixelStride = horizontal ? 4 : w * 4; // 行内相邻像素步长
  final lineStride = horizontal ? w * 4 : 4; // 行间步长
  for (var o = 0; o < outer; o++) {
    final base = o * lineStride;
    for (var c = 0; c < 4; c++) {
      var left = 0;
      var right = math.min(radius, inner - 1);
      var sum = 0;
      for (var i = left; i <= right; i++) {
        sum += src[base + i * pixelStride + c];
      }
      for (var x = 0; x < inner; x++) {
        // 窗口右界只增长到 inner-1；左界随 x 右移。
        final targetRight = x + radius;
        if (targetRight > right && right < inner - 1) {
          right++;
          sum += src[base + right * pixelStride + c];
        }
        final targetLeft = x - radius;
        if (targetLeft > left) {
          sum -= src[base + left * pixelStride + c];
          left++;
        }
        dst[base + x * pixelStride + c] = (sum / (right - left + 1)).round();
      }
    }
  }
}

/// USM 锐化：`out = v + amount * (v - blur(v))`。
///
/// [radius] 大、[amount] 小即「清晰度/局部对比度」；[radius] 小（1）、
/// [amount] 大即锐化。Alpha 通道不变。
void unsharpMaskRgba(Uint8List px, int w, int h, {required double amount, required int radius}) {
  if (amount <= 0 || radius < 1 || px.length < w * h * 4) return;
  final blurred = Uint8List.fromList(px);
  boxBlurRgba(blurred, w, h, radius);
  for (var i = 0; i < px.length; i += 4) {
    for (var c = 0; c < 3; c++) {
      final v = px[i + c].toDouble();
      final out = v + amount * (v - blurred[i + c]);
      px[i + c] = out.clamp(0, 255).round();
    }
  }
}

/// 全局对比度：以 128 为 pivot 线性缩放 RGB。
void adjustContrastRgba(Uint8List px, double factor) {
  if (factor == 1.0 || px.isEmpty) return;
  for (var i = 0; i < px.length; i += 4) {
    for (var c = 0; c < 3; c++) {
      final out = (px[i + c] - 128) * factor + 128;
      px[i + c] = out.clamp(0, 255).round();
    }
  }
}

/// Lanczos-3 重采样（两遍可分离：先水平后垂直）。
///
/// 用于超级分辨率放大：窗口 sinc·sinc 加权、边缘钳位、16.16 定点累加。
/// 返回新缓冲；[src] 不被修改。
Uint8List lanczosResizeRgba(Uint8List src, int sw, int sh, int dw, int dh) {
  if (sw <= 0 || sh <= 0 || dw <= 0 || dh <= 0) return src;
  if (sw == dw && sh == dh) return Uint8List.fromList(src);
  final tmp = Uint8List(dw * sh * 4);
  _resample(src, tmp, sw, sh, dw, horizontal: true);
  final dst = Uint8List(dw * dh * 4);
  _resample(tmp, dst, dw, sh, dh, horizontal: false);
  return dst;
}

/// 单方向重采样（[horizontal] 时把宽 sw→dw，否则把高 sh→dh）。
///
/// [d] 即目标方向尺寸：水平传 dw、垂直传 dh。注意水平通过后宽变为 dw，
/// 源/目标的行步长不同（sw*4 vs dw*4），必须分开算。
void _resample(Uint8List src, Uint8List dst, int sw, int sh, int d, {required bool horizontal}) {
  final srcSize = horizontal ? sw : sh;
  final dstSize = d;
  final lineCount = horizontal ? sh : sw;
  // 行内相邻像素步长 / 行间步长：
  // - 水平：src/dst 行内都是 4；行间源 sw*4、目标 dw*4（=dstSize*4）。
  // - 垂直：src/dst 行内都是 sw*4（dst 宽度即 dw=入参 sw）；行间都是 4。
  final srcPixelStride = horizontal ? 4 : sw * 4;
  final dstPixelStride = horizontal ? 4 : sw * 4;
  final srcLineStride = horizontal ? sw * 4 : 4;
  final dstLineStride = horizontal ? dstSize * 4 : 4;
  final (idx, wgt, taps, maxTaps) = _buildWeights(srcSize, dstSize);

  for (var line = 0; line < lineCount; line++) {
    final srcBase = line * srcLineStride;
    final dstBase = line * dstLineStride;
    for (var x = 0; x < dstSize; x++) {
      final off = x * maxTaps;
      final t = taps[x];
      var r = 0, g = 0, b = 0, a = 0;
      for (var k = 0; k < t; k++) {
        final si = srcBase + idx[off + k] * srcPixelStride;
        final wq = wgt[off + k];
        r += src[si] * wq;
        g += src[si + 1] * wq;
        b += src[si + 2] * wq;
        a += src[si + 3] * wq;
      }
      final di = dstBase + x * dstPixelStride;
      dst[di] = _fixRound(r);
      dst[di + 1] = _fixRound(g);
      dst[di + 2] = _fixRound(b);
      dst[di + 3] = _fixRound(a);
    }
  }
}

/// 16.16 定点结果 → 字节（四舍五入 + 钳位）。
int _fixRound(int v) {
  var r = (v + 32768) >> 16;
  if (r < 0) r = 0;
  if (r > 255) r = 255;
  return r;
}

/// Lanczos-3 核：|x| >= 3 时为 0（sinc 零点）。
double _lanczosKernel(double x) {
  const a = 3.0;
  final ax = x.abs();
  if (ax >= a) return 0.0;
  if (ax < 1e-9) return 1.0;
  final pix = math.pi * x;
  return (math.sin(pix) / pix) * (math.sin(pix / a) / (pix / a));
}

/// 预计算每个目标像素的 (源下标, 16.16 权重) 表；权重和规整为 65536。
///
/// 返回 (下标, 权重, 每目标 tap 数, 最大 tap 数)。平坦数组按目标像素分行。
(List<int>, List<int>, List<int>, int) _buildWeights(int srcSize, int dstSize) {
  final scale = srcSize / dstSize; // <1 为放大
  final support = 3.0 / scale; // 源像素半窗宽
  final maxTaps = math.min(srcSize, (support * 2).ceil() + 2);
  final idx = List<int>.filled(dstSize * maxTaps, 0);
  final wgt = List<int>.filled(dstSize * maxTaps, 0);
  final taps = List<int>.filled(dstSize, 0);

  for (var i = 0; i < dstSize; i++) {
    final center = (i + 0.5) * scale - 0.5;
    final left = (center - support).ceil();
    final right = (center + support).floor();
    final indices = <int>[];
    final weights = <double>[];
    var sum = 0.0;
    for (var j = left; j <= right; j++) {
      if (j < 0 || j >= srcSize) continue;
      final w = _lanczosKernel(j - center);
      if (w == 0) continue;
      indices.add(j);
      weights.add(w);
      sum += w;
    }
    if (indices.isEmpty) {
      // 极端退化：取最近邻。
      final near = center.round().clamp(0, srcSize - 1);
      idx[i * maxTaps] = near;
      wgt[i * maxTaps] = 65536;
      taps[i] = 1;
      continue;
    }
    var acc = 0;
    var maxK = 0;
    for (var k = 0; k < weights.length; k++) {
      final f = (weights[k] / sum * 65536).round();
      idx[i * maxTaps + k] = indices[k];
      wgt[i * maxTaps + k] = f;
      acc += f;
      if (f > wgt[i * maxTaps + maxK]) maxK = k;
    }
    wgt[i * maxTaps + maxK] += 65536 - acc; // 修正舍入，保证权重和精确
    taps[i] = weights.length;
  }
  return (idx, wgt, taps, maxTaps);
}
