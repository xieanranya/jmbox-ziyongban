/// 首页：顶部 promote 标签 + 分区内容网格（触底加载更多，内容区左右滑动切换分区）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_routes.dart';
import '../../core/constants/dimen.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/paged_card_grid.dart';
import '../../data/models/promote.dart';
import 'home_providers.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _scroll = ScrollController();

  /// 当前手势累计横向拖动距离（px），用于滑动切换分区。
  double _swipeDelta = 0;

  /// 切换分区：更新选中态并重置内容滚动位置。
  void _selectSection(int id) {
    ref.read(selectedSectionIdProvider.notifier).select(id);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  /// 内容区左滑→下一个分区、右滑→上一个分区；轻扫（速度）或拖过阈值（位移）触发，越界不动。
  void _onContentSwipeEnd(DragEndDetails details, List<PromoteSection> list, int selectedId) {
    final velocity = details.velocity.pixelsPerSecond.dx;
    if (_swipeDelta.abs() < 40 && velocity.abs() < 300) return;
    // 有轻扫速度时以速度方向为准，否则以拖动位移方向为准。
    final direction = (velocity.abs() >= 300 ? velocity : _swipeDelta) < 0 ? 1 : -1;
    final next = list.indexWhere((s) => s.id == selectedId) + direction;
    if (next < 0 || next >= list.length) return;
    _selectSection(list[next].id);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sections = ref.watch(promoteSectionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('JmBox'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '搜索',
            onPressed: () => context.push(AppRoutes.search),
          ),
        ],
      ),
      body: sections.when(
        loading: () => const SizedBox.shrink(),
        error: (error, _) => ScrollableStatusView(
          child: ErrorRetryView(
            error: error,
            onRetry: () => ref.invalidate(promoteSectionsProvider),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const ScrollableStatusView(
              child: EmptyView(message: '暂无推荐内容', icon: Icons.inbox_outlined),
            );
          }
          // 选中态由 provider 持有（跨刷新保留）；失效 id 回退到第一个分区。
          final savedId = ref.watch(selectedSectionIdProvider);
          final selectedId = list.any((s) => s.id == savedId) ? savedId! : list.first.id;
          return RefreshIndicator.adaptive(
            onRefresh: () async {
              ref.invalidate(promoteSectionsProvider);
              final fresh = await ref.read(promoteSectionsProvider.future);
              // 刷新当前分区：读 provider 而非闭包捕获，避免刷新期间切换分区后取到旧值。
              final id = ref.read(selectedSectionIdProvider);
              final valid = fresh.any((s) => s.id == id);
              ref.read(homeSectionPagingProvider(valid ? id! : fresh.first.id)).refresh();
            },
            child: Column(
              children: [
                _SectionTabs(
                  sections: list,
                  selectedId: selectedId,
                  onSelected: _selectSection,
                ),
                Expanded(
                  // 横向拖动与网格纵向滚动由手势竞技场按主轴方向自动仲裁，互不干扰。
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragStart: (_) => _swipeDelta = 0,
                    onHorizontalDragUpdate: (d) => _swipeDelta += d.delta.dx,
                    onHorizontalDragEnd: (d) => _onContentSwipeEnd(d, list, selectedId),
                    child: PagedCardGrid(
                      controller: ref.watch(homeSectionPagingProvider(selectedId)),
                      scrollController: _scroll,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 顶部标签栏：横向滚动 ChoiceChip；选中项变化时自动滚到可见区域。
class _SectionTabs extends StatefulWidget {
  const _SectionTabs({
    required this.sections,
    required this.selectedId,
    required this.onSelected,
  });

  final List<PromoteSection> sections;
  final int selectedId;
  final ValueChanged<int> onSelected;

  @override
  State<_SectionTabs> createState() => _SectionTabsState();
}

class _SectionTabsState extends State<_SectionTabs> {
  /// 每个标签的 GlobalKey：用于把选中标签滚动到可见区域。
  late final List<GlobalKey> _chipKeys = [for (final _ in widget.sections) GlobalKey()];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureSelectedVisible());
  }

  @override
  void didUpdateWidget(covariant _SectionTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sections.length != _chipKeys.length) {
      _chipKeys
        ..clear()
        ..addAll([for (final _ in widget.sections) GlobalKey()]);
    }
    if (oldWidget.selectedId != widget.selectedId) _ensureSelectedVisible();
  }

  /// 把选中标签滚动到接近居中位置。
  void _ensureSelectedVisible() {
    final index = widget.sections.indexWhere((s) => s.id == widget.selectedId);
    if (index < 0) return;
    final context = _chipKeys[index].currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(context, alignment: 0.5, duration: const Duration(milliseconds: 250));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Dimen.md, vertical: Dimen.sm),
        itemCount: widget.sections.length,
        separatorBuilder: (context, index) => const SizedBox(width: Dimen.sm),
        itemBuilder: (context, index) {
          final section = widget.sections[index];
          return ChoiceChip(
            key: _chipKeys[index],
            label: Text(section.title),
            selected: section.id == widget.selectedId,
            showCheckmark: false,
            onSelected: (_) => widget.onSelected(section.id),
          );
        },
      ),
    );
  }
}
