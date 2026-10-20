/// 书架仓库：磁盘持久化 + 内存缓存（专辑摘要列表）。
library;

import 'dart:convert';

import '../../core/storage/app_paths.dart';
import '../models/album.dart';

class BookshelfRepository {
  BookshelfRepository();

  List<AlbumBrief>? _cache;

  Future<List<AlbumBrief>> list() async {
    if (_cache != null) return List.of(_cache!);
    final file = AppPaths.bookshelf;
    if (!await file.exists()) {
      _cache = [];
      return const [];
    }
    try {
      final data = jsonDecode(await file.readAsString()) as List;
      _cache = data
          .whereType<Map>()
          .map((e) => AlbumBrief.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return List.of(_cache!);
    } catch (_) {
      _cache = [];
      return const [];
    }
  }

  /// 加入书架（已存在则移到顶部，与「新加入置顶」的展示排序一致）。
  Future<void> add(AlbumBrief album) async {
    await list();
    _cache!.removeWhere((e) => e.id == album.id);
    _cache!.insert(0, album);
    await _write();
  }

  /// 批量移出书架（一次写盘）。
  Future<void> removeMany(List<int> albumIds) async {
    await list();
    final ids = Set<int>.of(albumIds);
    _cache!.removeWhere((e) => ids.contains(e.id));
    await _write();
  }

  Future<bool> contains(int albumId) async {
    await list();
    return _cache!.any((e) => e.id == albumId);
  }

  Future<void> _write() async {
    final file = AppPaths.bookshelf;
    await file.writeAsString(jsonEncode(_cache!.map((e) => e.toJson()).toList()));
  }
}
