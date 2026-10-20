/// 专辑详情页数据流：详情、章节列表、书架翻转态、章节进度、评论分页。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../core/utils/paging.dart';
import '../../data/models/album.dart';
import '../../data/models/comment.dart';
import '../../data/providers.dart';

final albumDetailProvider = FutureProvider.autoDispose.family<AlbumDetail, int>((ref, id) {
  return ref.watch(apiRepositoryProvider).getAlbum(id);
});

/// 章节列表：已在仓库层（getAlbum）按 sort 升序兜底 + 排序，此处直接透传。
final albumChaptersProvider = Provider.autoDispose.family<List<Series>, int>((ref, id) {
  return ref.watch(albumDetailProvider(id)).value?.series ?? const <Series>[];
});

/// 某专辑的章节进度（chapterId，无记录为 null）：直读仓库，进阅读器返回后手动 invalidate。
final albumReadingProgressProvider = FutureProvider.autoDispose.family<int?, int>((ref, albumId) {
  return ref.read(readingHistoryRepositoryProvider).readProgress(albumId);
});

/// 评论分页控制器（仅评论 Tab 挂载时才拉取）。
final commentsControllerProvider = Provider.autoDispose
    .family<PagingController<int, CommentInfo>, int>((ref, albumId) {
      final api = ref.read(apiRepositoryProvider);
      final controller = pagingController<CommentInfo>((page) async {
        final info = await api.getComments(albumId, page);
        return (info.list, info.total);
      });
      ref.onDispose(controller.dispose);
      return controller;
    });
