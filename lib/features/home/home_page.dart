/// 首页：顶部标签栏（浏览分区 + 发现页迁入的 11 个分类）+ 分区内容网格
/// （触底加载更多，内容区左右滑动切换标签；分类标签带子分类/排序筛选栏）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_routes.dart';
import '../../core/constants/dimen.dart';
import '../../core/constants/sort.dart';
import '../../data/models/category.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/paged_card_grid.dart';
import 'home_providers.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _scroll = ScrollController();

  /// 当前手势累计横向拖动距离（px），用于滑动切换标签。
  double _swipeDelta = 0;

  /// 分类排序（默认=最新顺序；仅对分类标签生效）。
  CategorySort _sort = CategorySort.defaultOrder;

  /// 切换标签：更新选中态并重置内容滚动位置。
  void _selectTab(String key) {
    ref.read(selectedHomeTabProvider.notifier).select(key);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  /// 排序选择弹窗（参考图：请选择排序方式，竖排选项）。
  Future<void> _showSortDialog() async {
    final cs = Theme.of(context).colorScheme;
    final picked = await showDialog<CategorySort>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('请选择排序方式'),
        contentPadding: const EdgeInsets.symmetric(vertical: Dimen.sm),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final e in categorySortLabels.entries)
                InkWell(
                  onTap: () => Navigator.pop(ctx, e.key),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: Dimen.xl, vertical: 13),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            e.value,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: e.key == _sort
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (e.key == _sort)
                          Icon(Icons.check, size: 18, color: cs.primary),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _sort = picked);
  }

  /// 内容区左滑→下一个标签、右滑→上一个标签；轻扫（速度）或拖过阈值（位移）触发，越界不动。
  void _onContentSwipeEnd(DragEndDetails details, List<HomeTab> tabs, String selectedKey) {
    final velocity = details.velocity.pixelsPerSecond.dx;
    if (_swipeDelta.abs() < 40 && velocity.abs() < 300) return;
    // 有轻扫速度时以速度方向为准，否则以拖动位移方向为准。
    final direction = (velocity.abs() >= 300 ? velocity : _swipeDelta) < 0 ? 1 : -1;
    final next = tabs.indexWhere((t) => t.key == selectedKey) + direction;
    if (next < 0 || next >= tabs.length) return;
    _selectTab(tabs[next].key);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = ref.watch(homeTabsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('JmBox'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: '每周必看',
            onPressed: () => context.push(AppRoutes.weekly),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '搜索',
            onPressed: () => context.push(AppRoutes.search),
          ),
        ],
      ),
      body: tabs.when(
        loading: () => const SizedBox.shrink(),
        error: (error, _) => ScrollableStatusView(
          child: ErrorRetryView(
            error: error,
            onRetry: () => ref.invalidate(homeTabsProvider),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const ScrollableStatusView(
              child: EmptyView(message: '暂无推荐内容', icon: Icons.inbox_outlined),
            );
          }
          // 选中态由 provider 持有（跨刷新保留）；失效 key 回退到第一个标签。
          final savedKey = ref.watch(selectedHomeTabProvider);
          final selected = list.firstWhere((t) => t.key == savedKey, orElse: () => list.first);
          return RefreshIndicator.adaptive(
            onRefresh: () async {
              ref.invalidate(homeTabsProvider);
              final fresh = await ref.read(homeTabsProvider.future);
              // 刷新当前标签：读 provider 而非闭包捕获，避免刷新期间切换后取到旧值。
              final key = ref.read(selectedHomeTabProvider);
              final tab = fresh.firstWhere((t) => t.key == key, orElse: () => fresh.first);
              if (tab.isCategory) {
                ref.read(categoryPagingProvider(_catQueryKey(tab.category!))).refresh();
              } else {
                ref.read(homeSectionPagingProvider(tab.section!.id)).refresh();
              }
            },
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _TabBar(
                        tabs: list,
                        selectedKey: selected.key,
                        onSelected: _selectTab,
                      ),
                    ),
                    // 排序入口：永远固定在最右侧（不随标签滚动，参考视频样式）
                    _sortControl(),
                  ],
                ),
                Expanded(
                  // 横向拖动与网格纵向滚动由手势竞技场按主轴方向自动仲裁，互不干扰。
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragStart: (_) => _swipeDelta = 0,
                    onHorizontalDragUpdate: (d) => _swipeDelta += d.delta.dx,
                    onHorizontalDragEnd: (d) => _onContentSwipeEnd(d, list, selected.key),
                    child: selected.isCategory
                        ? _CategoryContent(
                            category: selected.category!,
                            sort: _sort,
                            scrollController: _scroll,
                          )
                        : PagedCardGrid(
                            controller: ref.watch(homeSectionPagingProvider(selected.section!.id)),
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

  /// 排序入口：三线图标 + 当前排序名（参考图右侧样式）。
  Widget _sortControl() {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: _showSortDialog,
      borderRadius: BorderRadius.circular(Dimen.rSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Dimen.md, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sort, size: 22, color: cs.onSurface),
            const SizedBox(height: 2),
            Text(categorySortLabels[_sort] ?? '默认',
                style: TextStyle(fontSize: 11, color: cs.onSurface)),
          ],
        ),
      ),
    );
  }

  /// 分类内容查询 key："slug|子slug|排序名"（固定无子分类筛选）。
  String _catQueryKey(CategoryItem category) =>
      '${category.slug}||${_sort.name}';
}

/// 分类标签内容：按所选排序分页的网格（无筛选栏）。
class _CategoryContent extends ConsumerWidget {
  const _CategoryContent({
    required this.category,
    required this.sort,
    required this.scrollController,
  });

  final CategoryItem category;
  final CategorySort sort;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queryKey = '${category.slug}||${sort.name}';
    return PagedCardGrid(
      controller: ref.watch(categoryPagingProvider(queryKey)),
      scrollController: scrollController,
    );
  }
}

/// 顶部标签栏：横向滚动 ChoiceChip；选中项变化时自动滚到可见区域。
class _TabBar extends StatefulWidget {
  const _TabBar({
    required this.tabs,
    required this.selectedKey,
    required this.onSelected,
  });

  final List<HomeTab> tabs;
  final String selectedKey;
  final ValueChanged<String> onSelected;

  @override
  State<_TabBar> createState() => _TabBarState();
}

class _TabBarState extends State<_TabBar> {
  /// 每个标签的 GlobalKey：用于把选中标签滚动到可见区域。
  late final List<GlobalKey> _chipKeys = [for (final _ in widget.tabs) GlobalKey()];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureSelectedVisible());
  }

  @override
  void didUpdateWidget(covariant _TabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tabs.length != _chipKeys.length) {
      _chipKeys
        ..clear()
        ..addAll([for (final _ in widget.tabs) GlobalKey()]);
    }
    if (oldWidget.selectedKey != widget.selectedKey) _ensureSelectedVisible();
  }

  /// 把选中标签滚动到接近居中位置。
  void _ensureSelectedVisible() {
    final index = widget.tabs.indexWhere((t) => t.key == widget.selectedKey);
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
        itemCount: widget.tabs.length,
        separatorBuilder: (context, index) => const SizedBox(width: Dimen.sm),
        itemBuilder: (context, index) {
          final tab = widget.tabs[index];
          return ChoiceChip(
            key: _chipKeys[index],
            label: Text(tab.title),
            selected: tab.key == widget.selectedKey,
            showCheckmark: false,
            onSelected: (_) => widget.onSelected(tab.key),
          );
        },
      ),
    );
  }
}
