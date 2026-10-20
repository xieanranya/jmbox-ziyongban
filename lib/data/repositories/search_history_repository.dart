/// 搜索历史仓库：磁盘持久化 + 内存缓存（关键词列表）。
library;

import 'dart:convert';

import '../../core/storage/app_paths.dart';

class SearchHistoryRepository {
  SearchHistoryRepository();

  static const _maxEntries = 20;

  List<String>? _cache;

  Future<List<String>> list() async {
    if (_cache != null) return List.of(_cache!);
    final file = AppPaths.searchHistory;
    if (!await file.exists()) {
      _cache = [];
      return const [];
    }
    try {
      final data = jsonDecode(await file.readAsString()) as List;
      _cache = data.whereType<String>().toList();
      return List.of(_cache!);
    } catch (_) {
      _cache = [];
      return const [];
    }
  }

  /// 新增关键词（去重，最新在前，上限 20 条，空词忽略）。
  Future<void> add(String keyword) async {
    final kw = keyword.trim();
    if (kw.isEmpty) return;
    await list();
    _cache!.remove(kw);
    _cache!.insert(0, kw);
    if (_cache!.length > _maxEntries) {
      _cache!.removeRange(_maxEntries, _cache!.length);
    }
    await _write();
  }

  Future<void> remove(String keyword) async {
    await list();
    _cache!.remove(keyword);
    await _write();
  }

  Future<void> clear() async {
    _cache = [];
    await _write();
  }

  Future<void> _write() async {
    final file = AppPaths.searchHistory;
    await file.writeAsString(jsonEncode(_cache!));
  }
}
