/// 画质增强档位参数与管线编排。
///
/// 管线顺序：Lanczos 超分放大 →（可选）预模糊降噪 → 清晰度（大半径 USM）
/// → 锐化（小半径 USM）→ 对比度。全部同步纯计算，跑在后台 isolate。
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../../../core/constants/enhance.dart';
import 'image_ops.dart';

/// 单档位增强参数。
class EnhanceParams {
  const EnhanceParams({
    required this.upscale,
    required this.targetMultiplier,
    required this.maxScale,
    required this.maxPixels,
    required this.preBlurRadius,
    required this.clarityRadius,
    required this.clarityAmount,
    required this.sharpenRadius,
    required this.sharpenAmount,
    required this.contrast,
  });

  /// 是否做超分放大（否 = 只锐化/清晰度/对比度）。
  final bool upscale;

  /// 放大目标 = 屏幕物理像素宽 × 本系数。
  final double targetMultiplier;

  /// 单边放大倍数上限。
  final double maxScale;

  /// 输出像素数上限（防低端机 OOM）。
  final int maxPixels;

  /// 预模糊半径（0 = 不降噪；抑制 JPEG 噪点后再锐化）。
  final int preBlurRadius;

  /// 清晰度（大半径 USM）参数。
  final int clarityRadius;
  final double clarityAmount;

  /// 锐化（小半径 USM）参数。
  final int sharpenRadius;
  final double sharpenAmount;

  /// 全局对比度系数（1 = 不变）。
  final double contrast;

  /// 标准：不放大；轻锐化 + 轻清晰度。适合原图已大于屏幕像素的页。
  static const standard = EnhanceParams(
    upscale: false,
    targetMultiplier: 0,
    maxScale: 1,
    maxPixels: 0,
    preBlurRadius: 0,
    clarityRadius: 4,
    clarityAmount: 0.28,
    sharpenRadius: 1,
    sharpenAmount: 0.55,
    contrast: 1.05,
  );

  /// 增强：Lanczos 放大到屏幕物理像素宽 + 强锐化。
  static const strong = EnhanceParams(
    upscale: true,
    targetMultiplier: 1.0,
    maxScale: 2.0,
    maxPixels: 4000000,
    preBlurRadius: 0,
    clarityRadius: 4,
    clarityAmount: 0.32,
    sharpenRadius: 1,
    sharpenAmount: 0.70,
    contrast: 1.06,
  );

  /// 超级：1.5 倍屏幕像素宽（封顶 2.5 倍原图）+ 预降噪 + 最强锐化。
  static const ultra = EnhanceParams(
    upscale: true,
    targetMultiplier: 1.5,
    maxScale: 2.5,
    maxPixels: 4000000,
    preBlurRadius: 1,
    clarityRadius: 5,
    clarityAmount: 0.36,
    sharpenRadius: 1,
    sharpenAmount: 0.85,
    contrast: 1.08,
  );

  static EnhanceParams of(EnhanceLevel level) => switch (level) {
    EnhanceLevel.off => standard, // 不会走到（调用方已拦截），占位
    EnhanceLevel.standard => standard,
    EnhanceLevel.strong => strong,
    EnhanceLevel.ultra => ultra,
    EnhanceLevel.ai => standard, // AI 档不走本管线（见 EnhanceService），占位
  };
}

/// 管线输出。
class EnhanceResult {
  const EnhanceResult(this.pixels, this.width, this.height);

  final Uint8List pixels;
  final int width;
  final int height;
}

/// 执行增强（同步，供 isolate 调用）。[targetWidth] 为屏幕物理像素宽。
EnhanceResult enhancePixels({
  required Uint8List pixels,
  required int width,
  required int height,
  required EnhanceLevel level,
  required int targetWidth,
}) {
  if (!level.enabled) return EnhanceResult(pixels, width, height);
  final params = EnhanceParams.of(level);
  var px = pixels;
  var w = width;
  var h = height;

  if (params.upscale && targetWidth > w) {
    var scale = (targetWidth * params.targetMultiplier / w).clamp(1.0, params.maxScale);
    // 像素封顶：按面积等比缩减（向下取整，确保不超上限）。
    var nw = (w * scale).floor();
    var nh = (h * scale).floor();
    if (nw * nh > params.maxPixels) {
      final k = math.sqrt(params.maxPixels / (w * h));
      nw = math.max(1, (w * k).floor());
      nh = math.max(1, (h * k).floor());
      // 双重保险：取整后仍超就再缩一档。
      while (nw * nh > params.maxPixels && (nw > 1 || nh > 1)) {
        if (nw >= nh) {
          nw--;
        } else {
          nh--;
        }
      }
    }
    if (nw > w && nh > h) {
      px = lanczosResizeRgba(px, w, h, nw, nh);
      w = nw;
      h = nh;
    }
  }

  if (params.preBlurRadius > 0) {
    boxBlurRgba(px, w, h, params.preBlurRadius, passes: 2);
  }
  if (params.clarityAmount > 0 && params.clarityRadius > 0) {
    unsharpMaskRgba(px, w, h, amount: params.clarityAmount, radius: params.clarityRadius);
  }
  if (params.sharpenAmount > 0 && params.sharpenRadius > 0) {
    unsharpMaskRgba(px, w, h, amount: params.sharpenAmount, radius: params.sharpenRadius);
  }
  if (params.contrast != 1.0) {
    adjustContrastRgba(px, params.contrast);
  }
  return EnhanceResult(px, w, h);
}
