/// 观看历史页数据流：本地阅读记录。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/album.dart';
import '../../data/providers.dart';

/// 本地持久化，全量无分页，最近观看在前。
///
/// 全局唯一历史状态源：详情页/章节列表记录观看时经此更新，历史页即时反映，无需刷新。
class ReadingHistoryNotifier extends AsyncNotifier<List<AlbumBrief>> {
  @override
  Future<List<AlbumBrief>> build() {
    return ref.watch(readingHistoryRepositoryProvider).list();
  }

  /// 记录看过某专辑（已存在则移到顶部）。失败静默，不打断跳转阅读。
  Future<void> add(AlbumBrief album) async {
    final repo = ref.read(readingHistoryRepositoryProvider);
    try {
      await repo.add(album);
      state = AsyncData(await repo.list());
    } catch (_) {
      // 写盘失败不影响跳转，下次进入自然重试。
    }
  }

  Future<void> removeMany(List<int> albumIds) async {
    final repo = ref.read(readingHistoryRepositoryProvider);
    await repo.removeMany(albumIds);
    state = AsyncData(await repo.list());
  }
}

final readingHistoryProvider = AsyncNotifierProvider<ReadingHistoryNotifier, List<AlbumBrief>>(
  ReadingHistoryNotifier.new,
);

/// 记录看过某专辑（跳转阅读器前调用）。
Future<void> recordAlbumView(WidgetRef ref, AlbumBrief album) {
  return ref.read(readingHistoryProvider.notifier).add(album);
}
