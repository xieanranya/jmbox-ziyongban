/// 书架页数据流：本地书架列表。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/album.dart';
import '../../data/providers.dart';

/// 书架列表（本地持久化，全量无分页，新加入置顶）。
///
/// 全局唯一书架状态源：详情页与书架页共用此 Provider，任一处增删都会即时反映到另一处，
/// 无需返回书架页手动刷新。
class BookshelfNotifier extends AsyncNotifier<List<AlbumBrief>> {
  @override
  Future<List<AlbumBrief>> build() {
    return ref.watch(bookshelfRepositoryProvider).list();
  }

  /// 加入书架（已存在则移到顶部）。
  Future<void> add(AlbumBrief album) async {
    final repo = ref.read(bookshelfRepositoryProvider);
    await repo.add(album);
    state = AsyncData(await repo.list());
  }

  Future<void> removeMany(List<int> albumIds) async {
    final repo = ref.read(bookshelfRepositoryProvider);
    await repo.removeMany(albumIds);
    state = AsyncData(await repo.list());
  }

  bool contains(int albumId) => state.value?.any((e) => e.id == albumId) ?? false;
}

final bookshelfProvider = AsyncNotifierProvider<BookshelfNotifier, List<AlbumBrief>>(
  BookshelfNotifier.new,
);
