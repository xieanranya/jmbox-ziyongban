/// 排行榜：日榜/周榜/月榜 + 分类筛选 + 排序 + 名次徽标卡片网格。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../core/constants/app_routes.dart';
import '../../core/constants/dimen.dart';
import '../../core/constants/sort.dart';
import '../../data/models/album.dart';
import '../../data/models/category.dart';
import '../../data/providers.dart';
import '../../shared/widgets/album_card.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/grid_utils.dart';
import 'ranking_providers.dart';

/// 排序展示文案（排行页专用）：最多观看 / 最多收藏 / 最高评分（不含最新）。
const Map<CategorySort, String> _sortLabels = {
  CategorySort.totalRanking: '最多观看',
  CategorySort.like: '最多收藏',
  CategorySort.pictures: '最高评分',
};

/// 榜单页签：日榜 / 周榜 / 月榜（接口真实榜单：mv_t / mv_w / mv_m）。
const List<(String, CategorySort)> _rankTabs = [
  ('日榜', CategorySort.todayRanking),
  ('周榜', CategorySort.weekRanking),
  ('月榜', CategorySort.monthRanking),
];

class RankingPage extends ConsumerStatefulWidget {
  const RankingPage({super.key});

  @override
  ConsumerState<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends ConsumerState<RankingPage> {
  CategorySort _sort = CategorySort.todayRanking;

  /// 排序显示文案：日/周/月榜等窗口榜单统一显示「最多观看」。
  String get _sortLabel => _sortLabels[_sort] ?? '最多观看';

  /// 分类 slug；空串表示全部。
  String _slug = '';

  String get _queryKey => '$_slug|${_sort.name}';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final categories = ref.watch(rankingCategoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('排行榜')),
      body: Column(
        children: [
          const SizedBox(height: Dimen.sm),
          // 日榜 / 周榜 / 月榜
          Container(
            margin: const EdgeInsets.symmetric(horizontal: Dimen.lg),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Row(
              children: [
                for (final (label, sort) in _rankTabs)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _sort = sort),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: _sort == sort ? cs.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: _sort == sort ? FontWeight.w700 : FontWeight.w500,
                            color: _sort == sort ? cs.onPrimary : cs.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Dimen.sm),
          // 分类 chips（全部 + 一级分类）
          SizedBox(
            height: 44,
            child: switch (categories) {
              AsyncData(:final value) => ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: Dimen.lg),
                  children: [
                    _categoryChip('全部', ''),
                    for (final c in value)
                      if (c.slug.isNotEmpty) _categoryChip(c.name, c.slug),
                  ],
                ),
              _ => const SizedBox.shrink(),
            },
          ),
          // 排序选择
          Padding(
            padding: const EdgeInsets.fromLTRB(Dimen.lg, Dimen.sm, Dimen.lg, 0),
            child: Row(
              children: [
                Text('排序',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                const SizedBox(width: Dimen.md),
                PopupMenuButton<CategorySort>(
                  initialValue: _sort,
                  onSelected: (v) => setState(() => _sort = v),
                  itemBuilder: (context) => [
                    for (final e in _sortLabels.entries)
                      PopupMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.visibility_outlined,
                            size: 16, color: cs.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text(_sortLabel,
                            style: const TextStyle(fontSize: 13)),
                        Icon(Icons.arrow_drop_down,
                            size: 20, color: cs.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Dimen.xs),
          // 榜单网格
          Expanded(
            child: RefreshIndicator.adaptive(
              onRefresh: () async {
                ref.read(rankingPagingProvider(_queryKey)).refresh();
              },
              child: _RankGrid(queryKey: _queryKey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(String label, String slug) {
    return Padding(
      padding: const EdgeInsets.only(right: Dimen.sm),
      child: ChoiceChip(
        label: Text(label),
        selected: _slug == slug,
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        onSelected: (_) => setState(() => _slug = slug),
      ),
    );
  }
}

/// 榜单网格：分页加载 + 名次徽标卡片。
class _RankGrid extends ConsumerWidget {
  const _RankGrid({required this.queryKey});

  final String queryKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(rankingPagingProvider(queryKey));
    return LayoutBuilder(
      builder: (context, constraints) => PagingListener<int, AlbumBrief>(
        controller: controller,
        builder: (context, state, fetchNextPage) => PagedGridView<int, AlbumBrief>(
          state: state,
          fetchNextPage: fetchNextPage,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(Dimen.lg),
          gridDelegate: albumGridDelegate(constraints.maxWidth - Dimen.lg * 2),
          showNoMoreItemsIndicatorAsGridChild: false,
          builderDelegate: pagedDelegate<AlbumBrief>(
            itemBuilder: (context, album, index) =>
                _RankCard(album: album, rank: index + 1),
            error: controller.error,
            onRetry: controller.refresh,
            fetchNextPage: fetchNextPage,
            emptyView: const EmptyView(message: '暂无排行内容', icon: Icons.leaderboard_outlined),
          ),
        ),
      ),
    );
  }
}

/// 名次卡片：封面 + 左上名次徽标 + 右下收藏心形 + 书名。
class _RankCard extends ConsumerStatefulWidget {
  const _RankCard({required this.album, required this.rank});

  final AlbumBrief album;
  final int rank;

  @override
  ConsumerState<_RankCard> createState() => _RankCardState();
}

class _RankCardState extends ConsumerState<_RankCard> {
  bool _fav = false;
  bool _busy = false;

  /// 名次徽标底色：1 金 / 2 红 / 3 紫 / 其余半透明黑。
  Color get _badgeColor => switch (widget.rank) {
    1 => const Color(0xFFE9B44C),
    2 => const Color(0xFFE05D5D),
    3 => const Color(0xFF8E7CC3),
    _ => Colors.black.withValues(alpha: 0.55),
  };

  Future<void> _toggleFav() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiRepositoryProvider).toggleFavorite(widget.album.id);
      if (mounted) setState(() => _fav = !_fav);
    } catch (_) {
      // 收藏失败静默（网络/登录态问题不影响浏览）
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(Dimen.rMd),
      onTap: () => context.push('${AppRoutes.albumDetail}/${widget.album.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: Dimen.xs,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Dimen.rMd),
            child: AspectRatio(
              aspectRatio: Dimen.coverAspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CoverImage(albumId: widget.album.id),
                  // 名次徽标
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _badgeColor,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${widget.rank}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  // 收藏心形
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: GestureDetector(
                      onTap: _toggleFav,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _fav ? Icons.favorite : Icons.favorite_border,
                          size: 17,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              widget.album.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
