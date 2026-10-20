/// 画质增强管线单测：尺寸数学、像素合法性、确定性、边界不崩。
///
/// 运行：flutter test test/features/reader/enhance_pipeline_test.dart
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:jmbox/core/constants/enhance.dart';
import 'package:jmbox/features/reader/enhance/enhance_pipeline.dart';
import 'package:jmbox/features/reader/enhance/enhance_service.dart';
import 'package:jmbox/features/reader/enhance/image_ops.dart';

/// 构造一张带边缘与渐变的测试图（RGBA 直排）。
Uint8List _testImage(int w, int h) {
  final px = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      // 左半灰度渐变 + 右半棋盘格，模拟漫画线条与网点。
      final v = x < w ~/ 2 ? (x * 255 ~/ math.max(1, w ~/ 2)) : ((x + y) % 2 == 0 ? 20 : 235);
      px[i] = v;
      px[i + 1] = v;
      px[i + 2] = v;
      px[i + 3] = 255;
    }
  }
  return px;
}

bool _allBytesInRange(Uint8List px) {
  for (final b in px) {
    if (b < 0 || b > 255) return false;
  }
  return true;
}

int _diffCount(Uint8List a, Uint8List b) {
  var n = 0;
  for (var i = 0; i < a.length && i < b.length; i++) {
    if (a[i] != b[i]) n++;
  }
  return n;
}

void main() {
  group('enhancePixels 尺寸数学', () {
    test('off 档原样返回', () {
      final src = _testImage(64, 90);
      final result = enhancePixels(
        pixels: src,
        width: 64,
        height: 90,
        level: EnhanceLevel.off,
        targetWidth: 1000,
      );
      expect(result.width, 64);
      expect(result.height, 90);
      expect(_diffCount(result.pixels, src), 0);
    });

    test('standard 档不放大', () {
      final src = _testImage(64, 90);
      final original = Uint8List.fromList(src);
      final result = enhancePixels(
        pixels: src,
        width: 64,
        height: 90,
        level: EnhanceLevel.standard,
        targetWidth: 1000,
      );
      expect(result.width, 64);
      expect(result.height, 90);
      // 锐化/对比度应改变像素（注意管线为原地修改，须先留副本再对比）。
      expect(_diffCount(result.pixels, original), greaterThan(0));
      expect(_allBytesInRange(result.pixels), isTrue);
    });

    test('strong 档放大到目标宽（2 倍封顶内）', () {
      final src = _testImage(100, 140);
      final result = enhancePixels(
        pixels: src,
        width: 100,
        height: 140,
        level: EnhanceLevel.strong,
        targetWidth: 300,
      );
      // scale = 300/100 = 3 → 封顶 maxScale 2.0 → 200×280。
      expect(result.width, 200);
      expect(result.height, 280);
      expect(_allBytesInRange(result.pixels), isTrue);
    });

    test('strong 档目标宽小于原图不放大', () {
      final src = _testImage(300, 420);
      final original = Uint8List.fromList(src);
      final result = enhancePixels(
        pixels: src,
        width: 300,
        height: 420,
        level: EnhanceLevel.strong,
        targetWidth: 200,
      );
      expect(result.width, 300);
      expect(result.height, 420);
      expect(_diffCount(result.pixels, original), greaterThan(0));
    });

    test('ultra 档按 maxPixels 封顶', () {
      final src = _testImage(1000, 1400);
      final result = enhancePixels(
        pixels: src,
        width: 1000,
        height: 1400,
        level: EnhanceLevel.ultra,
        targetWidth: 2000,
      );
      // 目标 3000×4200 = 12.6M > 4M 封顶 → 等比缩到 ≤4M。
      expect(result.width * result.height, lessThanOrEqualTo(4000000));
      expect(result.width, greaterThan(1000)); // 仍然放大过
      // 宽高比保持。
      expect(
        (result.width / result.height - 1000 / 1400).abs(),
        lessThan(0.01),
      );
    });

    test('确定性：同输入同输出', () {
      final a = _testImage(80, 112);
      final b = _testImage(80, 112);
      final ra = enhancePixels(
        pixels: a,
        width: 80,
        height: 112,
        level: EnhanceLevel.strong,
        targetWidth: 160,
      );
      final rb = enhancePixels(
        pixels: b,
        width: 80,
        height: 112,
        level: EnhanceLevel.strong,
        targetWidth: 160,
      );
      expect(_diffCount(ra.pixels, rb.pixels), 0);
    });

    test('极端小图不崩', () {
      for (final (w, h) in [(1, 1), (2, 3), (5, 1), (1, 7)]) {
        final src = _testImage(w, h);
        for (final level in [EnhanceLevel.standard, EnhanceLevel.strong, EnhanceLevel.ultra]) {
          final result = enhancePixels(
            pixels: src,
            width: w,
            height: h,
            level: level,
            targetWidth: 500,
          );
          expect(result.width, greaterThan(0));
          expect(result.height, greaterThan(0));
          expect(_allBytesInRange(result.pixels), isTrue);
        }
      }
    });
  });

  group('像素运算', () {
    test('盒式模糊不越界且趋于平滑', () {
      final w = 32;
      final h = 32;
      final px = _testImage(w, h);
      boxBlurRgba(px, w, h, 2);
      expect(_allBytesInRange(px), isTrue);
      // 模糊后相邻像素差应整体变小（方差下降）。
      double variance(Uint8List p) {
        final values = <int>[];
        for (var i = 0; i < p.length; i += 4) {
          values.add(p[i]);
        }
        final mean = values.reduce((a, b) => a + b) / values.length;
        return values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / values.length;
      }

      final before = variance(_testImage(w, h));
      expect(variance(px), lessThan(before));
    });

    test('USM 锐化增强边缘对比', () {
      final w = 16;
      final h = 16;
      final px = Uint8List(w * h * 4);
      // 竖直二值边缘：左黑右白。
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final i = (y * w + x) * 4;
          final v = x < w ~/ 2 ? 60 : 200;
          px[i] = v;
          px[i + 1] = v;
          px[i + 2] = v;
          px[i + 3] = 255;
        }
      }
      final edgeBefore = (px[(0 * w + w ~/ 2) * 4] - px[(0 * w + w ~/ 2 - 1) * 4]).abs();
      unsharpMaskRgba(px, w, h, amount: 0.8, radius: 1);
      final edgeAfter = (px[(0 * w + w ~/ 2) * 4] - px[(0 * w + w ~/ 2 - 1) * 4]).abs();
      expect(edgeAfter, greaterThan(edgeBefore));
      expect(_allBytesInRange(px), isTrue);
    });

    test('Lanczos 2×2 四色块放大到 4×4 保持象限结构', () {
      // 红 / 绿
      // 蓝 / 白
      final src = Uint8List.fromList([
        255, 0, 0, 255, 0, 255, 0, 255,
        0, 0, 255, 255, 255, 255, 255, 255,
      ]);
      final dst = lanczosResizeRgba(src, 2, 2, 4, 4);
      expect(dst.length, 4 * 4 * 4);
      // 象限均值（Lanczos 负瓣在硬边旁有振铃，均值可稀释）。
      List<int> quadAvg(int qx, int qy) {
        var r = 0, g = 0, b = 0;
        for (var y = qy * 2; y < qy * 2 + 2; y++) {
          for (var x = qx * 2; x < qx * 2 + 2; x++) {
            final i = (y * 4 + x) * 4;
            r += dst[i];
            g += dst[i + 1];
            b += dst[i + 2];
          }
        }
        return [r >> 2, g >> 2, b >> 2];
      }

      final tl = quadAvg(0, 0); // 左上 = 红
      expect(tl[0], greaterThan(150));
      expect(tl[1], lessThan(120));
      final tr = quadAvg(1, 0); // 右上 = 绿
      expect(tr[1], greaterThan(150));
      expect(tr[0], lessThan(120));
      final bl = quadAvg(0, 1); // 左下 = 蓝
      expect(bl[2], greaterThan(150));
      expect(bl[0], lessThan(120));
      final br = quadAvg(1, 1); // 右下 = 白
      expect(br[0], greaterThan(180));
      expect(br[1], greaterThan(180));
      expect(br[2], greaterThan(180));
      // 全图不应有大片死黑（步长错位会留下未写区域）。
      for (var i = 0; i < dst.length; i += 4) {
        expect(dst[i] + dst[i + 1] + dst[i + 2], greaterThan(30));
      }
    });

    test('Lanczos 放大保持尺寸与内容相关性', () {
      final w = 50;
      final h = 70;
      final src = _testImage(w, h);
      final dst = lanczosResizeRgba(src, w, h, 150, 210);
      expect(dst.length, 150 * 210 * 4);
      // 角落像素应接近原图角落（钳位行为）。
      int at(Uint8List p, int pw, int x, int y) => p[(y * pw + x) * 4];
      expect((at(dst, 150, 0, 0) - at(src, w, 0, 0)).abs(), lessThanOrEqualTo(40));
      expect((at(dst, 150, 149, 209) - at(src, w, 49, 69)).abs(), lessThanOrEqualTo(40));
      expect(_allBytesInRange(dst), isTrue);
    });

    test('Lanczos 缩放到相同尺寸返回等价副本', () {
      final src = _testImage(20, 30);
      final dst = lanczosResizeRgba(src, 20, 30, 20, 30);
      expect(_diffCount(src, dst), 0);
    });
  });

  group('EnhanceService（端到端 + 缓存）', () {
    test('原图 → 增强图 → 二次命中缓存同一实例', () async {
      const w = 40;
      const h = 56;
      final px = _testImage(w, h);
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(px, w, h, ui.PixelFormat.rgba8888, completer.complete);
      final image = await completer.future;

      final enhanced = await EnhanceService.instance.enhance(
        key: '999/0001.webp',
        source: image,
        level: EnhanceLevel.strong,
        targetWidth: 80,
      );
      expect(enhanced, isNotNull);
      expect(enhanced!.width, 80);
      expect(enhanced.height, 112);

      final again = await EnhanceService.instance.enhance(
        key: '999/0001.webp',
        source: image,
        level: EnhanceLevel.strong,
        targetWidth: 80,
      );
      expect(identical(again, enhanced), isTrue);

      // off 档直接返回 null（不进管线）。
      final off = await EnhanceService.instance.enhance(
        key: '999/0001.webp',
        source: image,
        level: EnhanceLevel.off,
        targetWidth: 80,
      );
      expect(off, isNull);

      image.dispose();
      // 收尾：单例缓存释放（本文件最后一个用例）。
      EnhanceService.instance.dispose();
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
