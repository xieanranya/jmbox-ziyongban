/// 画质增强门面：阅读器页面的唯一入口。
///
/// 两条链路：
/// - 经典档（标准/增强/超级）：[compute] 交后台 isolate 跑 [enhancePixels]；
/// - AI 档（[EnhanceLevel.ai]）：顺序队列串行跑 TFLite 推理（重，同时只跑一个），
///   同页去重、队列封顶；模型字节由主 isolate 经 rootBundle 取一次缓存。
///
/// 任何一步失败都返回 null，调用方保持原图。结果进 LRU 缓存（缓存持有，调用方不 dispose）。
/// 单例：缓存与模型字节为 App 级共享资源。
library;

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../../../core/constants/enhance.dart';
import 'ai_super_res.dart';
import 'enhance_cache.dart';
import 'enhance_pipeline.dart';

class EnhanceService {
  EnhanceService._();

  static final EnhanceService instance = EnhanceService._();

  final EnhanceImageCache _cache = EnhanceImageCache();

  /// 经典档后台在途数上限：超过直接放弃（该页保持原图），防快滚时刷屏。
  static const _maxInflight = 2;

  int _inflight = 0;

  // ---- AI 档：串行队列 ----

  /// AI 推理进行中（推理重，全局同时只跑一个）。
  bool _aiRunning = false;

  /// AI 等待队列长度上限：超过直接放弃（该页保持原图）。
  static const _maxAiQueue = 4;

  final List<_AiRequest> _aiQueue = [];

  /// 同页去重：cacheKey → 进行中的 Future。
  final Map<String, Future<ui.Image?>> _aiPending = {};

  /// 模型字节（主 isolate 取一次，之后各请求复用）。
  Uint8List? _aiModelBuffer;

  /// 增强一页。返回增强后的 [ui.Image]（缓存持有，调用方不得 dispose）；
  /// 返回 null = 未增强（调用方保持原图）。
  ///
  /// [key] 形如 `章节id/图片名`；[targetWidth] 为屏幕物理像素宽。
  Future<ui.Image?> enhance({
    required String key,
    required ui.Image source,
    required EnhanceLevel level,
    required int targetWidth,
  }) async {
    if (!level.enabled) return null; // off 档不走本服务（调用方保持原图）
    final cacheKey = '$key@${level.value}';
    final cached = _cache.get(cacheKey);
    if (cached != null) return cached;

    final data = await source.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;
    final pixels = data.buffer.asUint8List();

    if (level.isAi) return _enhanceAi(cacheKey, pixels, source.width, source.height);
    if (_inflight >= _maxInflight) return null;

    _inflight++;
    try {
      final result = await compute(_enhanceInBackground, (
        pixels: pixels,
        width: source.width,
        height: source.height,
        level: level,
        targetWidth: targetWidth,
      ));
      final image = await _decode(result.pixels, result.width, result.height);
      _cache.put(cacheKey, image);
      return image;
    } catch (_) {
      return null; // 后台失败：静默保持原图
    } finally {
      _inflight--;
    }
  }

  // ---- AI 链路 ----

  Future<ui.Image?> _enhanceAi(String cacheKey, Uint8List pixels, int width, int height) async {
    final pending = _aiPending[cacheKey];
    if (pending != null) return pending; // 同页已在进行/排队
    if (_aiQueue.length >= _maxAiQueue) return null;

    final completer = Completer<ui.Image?>();
    _aiPending[cacheKey] = completer.future;
    _aiQueue.add(_AiRequest(cacheKey, pixels, width, height, completer));
    _pumpAi();
    return completer.future;
  }

  Future<void> _pumpAi() async {
    if (_aiRunning) return;
    _aiRunning = true;
    try {
      while (_aiQueue.isNotEmpty) {
        final request = _aiQueue.removeAt(0);
        if (request.completer.isCompleted) continue;
        try {
          final buffer = _aiModelBuffer ??= await loadAiModelBuffer();
          final result = await compute(aiSuperResInBackground, (
            modelBuffer: buffer,
            pixels: request.pixels,
            width: request.width,
            height: request.height,
          ));
          final image = await _decode(result.pixels, result.width, result.height);
          _cache.put(request.cacheKey, image);
          request.completer.complete(image);
        } catch (_) {
          request.completer.complete(null);
        } finally {
          _aiPending.remove(request.cacheKey);
        }
      }
    } finally {
      _aiRunning = false;
    }
  }

  // ---- 公共 ----

  Future<ui.Image> _decode(Uint8List pixels, int width, int height) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(pixels, width, height, ui.PixelFormat.rgba8888, completer.complete);
    return completer.future;
  }

  /// 换章/退出阅读器时释放该章增强图。
  void evictChapter(int chapterId) => _cache.evictChapter(chapterId);

  void dispose() => _cache.clear();
}

/// AI 队列项。
class _AiRequest {
  const _AiRequest(this.cacheKey, this.pixels, this.width, this.height, this.completer);

  final String cacheKey;
  final Uint8List pixels;
  final int width;
  final int height;
  final Completer<ui.Image?> completer;
}

/// [compute] 入口（要求顶层函数）：纯计算，无 IO、无 Flutter 依赖。
EnhanceResult _enhanceInBackground((
  {Uint8List pixels,
  int width,
  int height,
  EnhanceLevel level,
  int targetWidth}
) msg) => enhancePixels(
  pixels: msg.pixels,
  width: msg.width,
  height: msg.height,
  level: msg.level,
  targetWidth: msg.targetWidth,
);
