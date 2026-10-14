/// 阅读器页面：竖排连续滚动，承载单页组件与跳页定位。
///
/// [ReaderController] 负责页面流状态、决策与会话级缓存（纯 Dart 可单测），[_ReaderViewState]
/// 只做 Flutter 侧绑定（滚动控制与可视位置监听）并注入数据源。加载态由控制器驱动，
/// 宿主用单个 ListenableBuilder 订阅，不订阅任何 provider。跳页「先推页码再滚动 + 等帧二次确认」。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../core/constants/reader_config.dart';
import '../../data/models/album.dart';
import '../../shared/widgets/async_view.dart';
import 'page_geometry.dart';
import 'reader_controller.dart';
import 'reader_providers.dart';
import 'widgets/reader_page_image.dart';
import 'widgets/reader_status_bar.dart';

/// 阅读器入口：校验章节 id 后交 [_ReaderView]；加载态由控制器驱动。
class ReaderPage extends StatelessWidget {
  const ReaderPage({super.key, required this.albumId, required this.chapterId});

  /// 路由 path 参数中的专辑 id；null 说明未携带。
  final int? albumId;

  /// 路由 path 参数中的章节 id；null 说明深链非法。
  final int? chapterId;

  @override
  Widget build(BuildContext context) {
    final id = chapterId;
    if (id == null) {
      return const Scaffold(
        body: EmptyView(message: '无效的章节链接', icon: Icons.link_off),
      );
    }
    return _ReaderView(albumId: albumId, initialChapterId: id);
  }
}

/// 阅读器主体：控制器与滚动绑定。传初始章节 id 与所属专辑 id，章节列表与数据由控制器自取。
class _ReaderView extends ConsumerStatefulWidget {
  const _ReaderView({this.albumId, required this.initialChapterId});

  /// 所属专辑 id（可空）：随控制器持有，供按专辑维度的功能使用。
  final int? albumId;

  final int initialChapterId;

  @override
  ConsumerState<_ReaderView> createState() => _ReaderViewState();
}

class _ReaderViewState extends ConsumerState<_ReaderView> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();

  late final ReaderController _controller;

  /// 会话级页面几何缓存：chapterId → 该章各页高宽比。属渲染测量数据，
  /// 宿主持有、随页面释放，控制器不感知。
  final Map<int, PageGeometry> _geometryCache = {};

  @override
  void initState() {
    super.initState();
    // 数据源经 readerDataSourceProvider 组装注入；控制器不感知 ProviderContainer，缓存随其 dispose 释放。
    _controller = ReaderController(
      dataSource: ref.read(readerDataSourceProvider),
      albumId: widget.albumId,
      initialChapterId: widget.initialChapterId,
      requestScroll: _settleScroll,
    );
    _itemPositionsListener.itemPositions.addListener(_onPositionsChanged);
  }

  @override
  void dispose() {
    _itemPositionsListener.itemPositions.removeListener(_onPositionsChanged);
    // 控制器持有会话级章节/scramble 缓存，dispose 即释放，宿主退出无需额外清理。
    _controller.dispose();
    super.dispose();
  }

  /// 可视位置变化 → 交给 controller 判定当前页。
  void _onPositionsChanged() {
    if (!mounted) return;
    _controller.updateFromPositions(
      _itemPositionsListener.itemPositions.value.map(
        (p) => (index: p.index, leading: p.itemLeadingEdge, trailing: p.itemTrailingEdge),
      ),
    );
  }

  /// 落位确认：跳页后等帧复查，首帧量不准则再滚一次。
  Future<void> _settleScroll(int target) async {
    if (!_itemScrollController.isAttached) return;
    _itemScrollController.jumpTo(index: target);
    for (var i = 0; i < kReaderJumpSettleAttempts; i++) {
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;
      final positions = _itemPositionsListener.itemPositions.value;
      if (positions.isEmpty) return;
      final firstIndex = positions.map((p) => p.index).reduce(math.min);
      if (firstIndex == target) return;
      _itemScrollController.jumpTo(index: target);
    }
  }

  /// 本章页面几何（随读随测）：宿主持有，控制器不感知渲染测量数据。
  PageGeometry _geometryFor(int chapterId) =>
      _geometryCache.putIfAbsent(chapterId, PageGeometry.new);

  @override
  Widget build(BuildContext context) {
    // 单一 ListenableBuilder 订阅控制器：加载态切换、换章、页码/控制栏变化都经此刷新。
    return Scaffold(
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.isLoading) return const LoadingView();
          final error = _controller.currentChapterError;
          if (error != null) {
            return ErrorRetryView(error: error, onRetry: _controller.retryCurrentChapter);
          }
          return _buildChapter(_controller.chapterId, _controller.currentChapter!);
        },
      ),
    );
  }

  /// 单章阅读视图：画面列表在下、顶/底控制栏浮于其上（外层 ListenableBuilder 已订阅变化）。
  Widget _buildChapter(int chapterId, Chapter chapter) {
    final images = chapter.images;
    if (images.isEmpty) {
      return const EmptyView(message: '本章没有可阅读的图片');
    }
    final geometry = _geometryFor(chapterId);
    final viewportWidth = MediaQuery.sizeOf(context).width;

    return Stack(
      children: [
        Positioned.fill(child: _buildPageList(chapterId, images, geometry, viewportWidth)),
        Positioned.fill(child: ReaderStatusBar(controller: _controller)),
      ],
    );
  }

  /// 竖排连续滚动列表：点击切控制栏限中央热区（见 [_onTapUp]），换章经 key 重建以重置滚动落点。
  Widget _buildPageList(
    int chapterId,
    List<String> images,
    PageGeometry geometry,
    double viewportWidth,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: _onTapUp,
      child: ScrollablePositionedList.builder(
        key: ValueKey(chapterId),
        itemCount: images.length,
        initialScrollIndex: _controller.currentPage.clamp(0, images.length - 1),
        itemScrollController: _itemScrollController,
        itemPositionsListener: _itemPositionsListener,
        physics: const ClampingScrollPhysics(),
        itemBuilder: (context, index) {
          return ReaderPageImage(
            // key 含章节 id：换章后即使 index 相同也是不同图片，强制重建。
            key: ValueKey('$chapterId-$index'),
            chapterId: chapterId,
            imageName: images[index],
            index: index,
            geometry: geometry,
            viewportWidth: viewportWidth,
            // 取图/取 scramble 经控制器：会话级 memo 缓存，多页共享一次 scramble 解析。
            readPhoto: _controller.readPhoto,
            scrambleOf: _controller.scramble,
          );
        },
      ),
    );
  }

  /// 中央点击热区判定：仅当点击落在屏幕中间的矩形内才切换控制栏
  void _onTapUp(TapUpDetails details) {
    final size = MediaQuery.sizeOf(context);
    final offset = details.globalPosition;
    final inWidth = (offset.dx - size.width / 2).abs() <= size.width * kReaderTapZoneWidthFactor / 2;
    final inHeight = (offset.dy - size.height / 2).abs() <= size.height * kReaderTapZoneHeightFactor / 2;
    if (inWidth && inHeight) _controller.toggleControls();
  }
}
