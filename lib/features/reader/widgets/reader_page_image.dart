/// 阅读器单页图片：取字节(经控制器) → 解码重排 → 画质增强 → RawImage 显示。
///
/// JM 章节图需先分块还原（[_decodeImage] 返回 [ui.Image]），无法走 ImageProvider，只能异步解码后直显。
/// 本 item 从首次布局起就要有接近真实的高度：未加载时用 [PageGeometry.aspectOf] 撑估算占位高，
/// 解码后用真实宽高 [PageGeometry.record] 回填。取图/scramble 经闭包注入（背后为控制器会话级 memo）。
///
/// 画质增强（[EnhanceLevel] 非 off）时：原图先上屏，增强完成后原位替换——
/// 增强图由 [EnhanceService] 缓存持有（本组件只借不还，不参与 dispose）。
library;

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/constants/dimen.dart';
import '../../../core/constants/enhance.dart';
import '../../../core/utils/jm_crypto.dart';
import '../enhance/enhance_service.dart';
import '../page_geometry.dart';

/// 转圈延迟出现的时间：命中磁盘缓存的页几乎瞬间解出，转圈立刻出现再消失就是一下灰闪。
const Duration _spinnerDelay = Duration(milliseconds: 180);

/// 阅读器的一页漫画。
class ReaderPageImage extends StatefulWidget {
  const ReaderPageImage({
    super.key,
    required this.chapterId,
    required this.imageName,
    required this.index,
    required this.geometry,
    required this.viewportWidth,
    required this.readPhoto,
    required this.scrambleOf,
    this.enhanceLevel = EnhanceLevel.off,
    this.enhanceTargetWidth = 0,
  });

  /// 章节 id（取图与分块算法的 id 入参）。
  final int chapterId;

  /// 图片文件名，如 `0001.webp`。
  final String imageName;

  /// 页序号（0 基），用于几何记录与占位查询。
  final int index;

  /// 本章页面几何（随读随测）。
  final PageGeometry geometry;

  /// 视口宽度（逻辑像素）：解码后按此宽显示，占位高据此估算。
  final double viewportWidth;

  /// 取某页图片字节（背后为控制器会话级缓存/仓库磁盘缓存）。
  final Future<Uint8List> Function(int chapterId, String imageName) readPhoto;

  /// 取某章 scramble id（背后为控制器 memo，多页共享一次解析）。
  final Future<int> Function(int chapterId) scrambleOf;

  /// 画质增强档位；off = 原图直显。
  final EnhanceLevel enhanceLevel;

  /// 增强放大目标宽（屏幕物理像素）：enhanceLevel 为 off 时忽略。
  final int enhanceTargetWidth;

  @override
  State<ReaderPageImage> createState() => _ReaderPageImageState();
}

class _ReaderPageImageState extends State<ReaderPageImage> {
  ui.Image? _image;

  /// [_image] 是否由本组件独占持有（原图 = true 需 dispose；增强图归缓存，false）。
  bool _imageOwned = false;

  /// AI 增强进行中（推理数秒，挂个小徽标告知用户，不挡阅读）。
  bool _enhancing = false;

  bool _loading = true;
  bool _failed = false;
  bool _spinnerReady = false;
  Timer? _spinnerTimer;

  // 本次加载的代际标识：widget 参数变化或重试时递增，旧回调据此丢弃结果。
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ReaderPageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chapterId != widget.chapterId ||
        oldWidget.imageName != widget.imageName ||
        oldWidget.enhanceLevel != widget.enhanceLevel ||
        oldWidget.enhanceTargetWidth != widget.enhanceTargetWidth) {
      _releaseImage();
      _enhancing = false;
      _loading = true;
      _failed = false;
      _load();
    }
  }

  void _scheduleSpinner() {
    _spinnerTimer?.cancel();
    _spinnerReady = false;
    _spinnerTimer = Timer(_spinnerDelay, () {
      if (mounted) setState(() => _spinnerReady = true);
    });
  }

  Future<void> _load() async {
    final generation = ++_generation;
    // 每一代加载（参数变化/重试）都重新计时，缓存命中时不出现短暂灰闪。
    _scheduleSpinner();
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final bytes = await widget.readPhoto(widget.chapterId, widget.imageName);
      // scramble 随页自取：控制器 memo 缓存，多页共享一次解析；await 确保用正确阈值解码。
      final scrambleId = await widget.scrambleOf(widget.chapterId);
      final image = await _decodeImage(
        bytes,
        scrambleId: scrambleId,
        id: widget.chapterId,
        filename: widget.imageName,
      );
      if (!mounted || generation != _generation) {
        image.dispose();
        return;
      }
      _spinnerTimer?.cancel();
      // 回填真实尺寸，驱动本章中位数估算收敛（进度条占位随之变准）。
      // 增强为等比放大，宽高比不变，几何记录用原图尺寸即可。
      widget.geometry.record(widget.index, image.width, image.height);
      setState(() {
        _releaseImage();
        _image = image;
        _imageOwned = true;
        _loading = false;
      });

      final level = widget.enhanceLevel;
      if (!level.enabled) return;

      // 增强开：后台管线处理，完成后原位替换（失败/过熟则保持原图）。
      // AI 档推理要数秒，先挂徽标；经典档几百毫秒，不打扰。
      if (level.isAi && mounted) setState(() => _enhancing = true);
      final enhanced = await EnhanceService.instance.enhance(
        key: '${widget.chapterId}/${widget.imageName}',
        source: image,
        level: level,
        targetWidth: widget.enhanceTargetWidth,
      );
      if (!mounted || generation != _generation) return; // 增强图归缓存所有，无需 dispose
      if (_enhancing) setState(() => _enhancing = false);
      if (enhanced != null && !identical(enhanced, _image)) {
        setState(() {
          _releaseImage();
          _image = enhanced;
          _imageOwned = false; // 缓存持有，本组件不 dispose
        });
      }
    } catch (_) {
      if (!mounted || generation != _generation) return;
      _spinnerTimer?.cancel();
      setState(() {
        _enhancing = false;
        _loading = false;
        _failed = true;
      });
    }
  }

  void _retry() {
    _releaseImage();
    _load();
  }

  /// 释放当前图：仅 dispose 本组件独占持有的原图；增强图归缓存，只断引用。
  void _releaseImage() {
    if (_imageOwned) _image?.dispose();
    _image = null;
    _imageOwned = false;
  }

  @override
  void dispose() {
    _generation++;
    _spinnerTimer?.cancel();
    _releaseImage();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aspect = widget.geometry.aspectOf(widget.index);
    final placeholderHeight = widget.viewportWidth * aspect;
    final bg = Theme.of(context).colorScheme.surface;

    final image = _image;
    Widget child;
    if (_failed && image == null) {
      child = _buildError(context);
    } else if (image != null) {
      child = RawImage(
        image: image,
        fit: BoxFit.contain,
        alignment: Alignment.topCenter,
        width: widget.viewportWidth,
        height: placeholderHeight,
        // 增强图通常大于显示尺寸（供系统降采样），用中等过滤避免摩尔纹；
        // 原图维持既有默认过滤。
        filterQuality: _imageOwned ? FilterQuality.low : FilterQuality.medium,
      );
      if (_enhancing) {
        child = Stack(
          children: [
            Positioned.fill(child: child),
            Positioned(left: 0, right: 0, bottom: Dimen.md, child: Center(child: _aiBadge(context))),
          ],
        );
      }
    } else {
      child = _loading && _spinnerReady
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(height: 12),
                  Text('正在加载第 ${widget.index + 1} 页', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            )
          : const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: Container(
        width: widget.viewportWidth,
        // 固定占位高：无论是否加载完成都撑住，保证列表总高稳定、跳页落点准确。
        height: placeholderHeight,
        color: bg,
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  /// AI 增强中徽标：底部居中的小胶囊（转圈 + 文案），不拦截阅读手势。
  Widget _aiBadge(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Dimen.md, vertical: Dimen.xs + 2),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(Dimen.rMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: Dimen.sm),
          Text('AI 增强中', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    // 与正常页同一底色（surface），失败态只靠图标与文案表达，不再用红底打断阅读连贯性。
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _retry,
      child: Container(
        color: scheme.surface,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined, size: 28, color: scheme.error),
            const SizedBox(height: 12),
            Text(
              '第 ${widget.index + 1} 页加载失败，点击重试',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- 解码（含重排）----

/// 用 dart:ui（Skia）解码图片字节并还原分块，返回可直接显示的 [ui.Image]。
/// GIF 或未打乱（blockNum == 0）时直接解码。重排用 Canvas 逐块搬运（等宽等高、整数偏移），
/// 不导出像素、不重新编码，接缝与整图连续解码一致。
Future<ui.Image> _decodeImage(
  Uint8List bytes, {
  required int scrambleId,
  required int id,
  required String filename,
}) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  codec.dispose(); // 帧已取出，codec 不再需要
  // GIF 不打乱分块
  if (_isGif(bytes)) return image;
  final blockNum = calculateBlockNum(scrambleId, id, filename);
  if (blockNum <= 1) return image;

  final width = image.width;
  final height = image.height;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final base = height ~/ blockNum;
  final remainder = height % blockNum;
  for (var i = 0; i < blockNum; i++) {
    var blockH = base;
    // 源图当前块的 Y 轴起点（从底部往上取块）
    final srcY = height - (base * (i + 1)) - remainder;
    // 目标图当前块的 Y 轴起点（从顶部往下放块）
    var dstY = base * i;
    // 第一块补上余数高度，确保拼接完整
    if (i == 0) {
      blockH += remainder;
    } else {
      dstY += remainder;
    }
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, srcY.toDouble(), width.toDouble(), blockH.toDouble()),
      ui.Rect.fromLTWH(0, dstY.toDouble(), width.toDouble(), blockH.toDouble()),
      ui.Paint(),
    );
  }
  final picture = recorder.endRecording();
  final restored = await picture.toImage(width, height);
  image.dispose();
  picture.dispose();
  return restored;
}

// ---- 格式识别 ----

/// 判断是否为 GIF（魔数 "GIF8"）。
bool _isGif(Uint8List bytes) =>
    bytes.length >= 4 &&
    bytes[0] == 0x47 &&
    bytes[1] == 0x49 &&
    bytes[2] == 0x46 &&
    bytes[3] == 0x38;
