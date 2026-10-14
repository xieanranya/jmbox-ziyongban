/// 分页列表页壳：分页生命周期 + 可选筛选栏插槽。
///
/// 依赖：PagedCardGrid、FilterBar（插槽）。
/// 使用方：分类/搜索/收藏/每周连载/每周必看/推荐分区列表页。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../data/models/album.dart';
import '../../core/utils/paging.dart';
import 'paged_card_grid.dart';

class RemoteGridPage extends ConsumerStatefulWidget {
  const RemoteGridPage({
    super.key,
    required this.title,
    required this.fetchPage,
    this.refreshKey,
    this.filterBar,
  });

  final String title;

  /// 拉取第 [page] 页（从 1 起），返回（条目, 总数；无总数接口传 null）。
  final Future<(List<AlbumBrief> items, int? total)> Function(int page) fetchPage;

  /// 筛选/查询状态（需实现 ==）；变化时重新加载并回到顶部。
  final Object? refreshKey;

  final Widget? filterBar;

  @override
  ConsumerState<RemoteGridPage> createState() => _RemoteGridPageState();
}

class _RemoteGridPageState extends ConsumerState<RemoteGridPage> {
  /// 闭包读取当前 fetchPage：筛选变化只需 refresh，无需重建控制器。
  late final PagingController<int, AlbumBrief> _controller = pagingController(
    (page) => widget.fetchPage(page),
  );
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(RemoteGridPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshKey != oldWidget.refreshKey) {
      _controller.refresh();
      if (_scroll.hasClients) _scroll.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filterBar = widget.filterBar;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          ?filterBar,
          Expanded(
            child: PagedCardGrid(controller: _controller, scrollController: _scroll),
          ),
        ],
      ),
    );
  }
}
