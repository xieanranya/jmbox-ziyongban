/// 分页卡片网格：PagingListener + PagedGridView + AlbumCard。
///
/// 依赖：AlbumCard、grid_utils、async_view。
/// 使用方：RemoteGridPage、首页分区。
library;

import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../core/constants/dimen.dart';
import '../../data/models/album.dart';
import 'album_card.dart';
import 'async_view.dart';
import 'grid_utils.dart';

class PagedCardGrid extends StatelessWidget {
  const PagedCardGrid({
    super.key,
    required this.controller,
    this.scrollController,
    this.padding = const EdgeInsets.all(Dimen.lg),
  });

  final PagingController<int, AlbumBrief> controller;
  final ScrollController? scrollController;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => PagingListener<int, AlbumBrief>(
        controller: controller,
        builder: (context, state, fetchNextPage) => PagedGridView<int, AlbumBrief>(
          state: state,
          fetchNextPage: fetchNextPage,
          scrollController: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: padding,
          gridDelegate: albumGridDelegate(constraints.maxWidth - padding.horizontal),
          showNoMoreItemsIndicatorAsGridChild: false,
          builderDelegate: pagedDelegate<AlbumBrief>(
            itemBuilder: (context, album, index) => AlbumCard(album: album),
            error: controller.error,
            onRetry: controller.refresh,
            fetchNextPage: fetchNextPage,
            emptyView: const EmptyView(message: '暂无内容', icon: Icons.inbox_outlined),
          ),
        ),
      ),
    );
  }
}
