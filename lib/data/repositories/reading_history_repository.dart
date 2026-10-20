/// 阅读历史仓库：磁盘持久化 + 内存缓存（看过啥 + 看到哪章）。
library;

import 'dart:convert';

import '../../core/storage/app_paths.dart';
import '../../core/utils/json_utils.dart';
import '../models/album.dart';

class ReadingHistoryRepository {
  ReadingHistoryRepository();

  /// 看过啥（专辑列表）。
  List<AlbumBrief>? _viewedCache;

  /// 看到哪章（albumId → chapterId）。
  Map<String, int>? _progressCache;

  Future<List<AlbumBrief>> list() async {
    if (_viewedCache != null) return List.of(_viewedCache!);
    final file = AppPaths.history;
    if (!await file.exists()) {
      _viewedCache = [];
      return const [];
    }
    try {
      final data = jsonDecode(await file.readAsString()) as List;
      _viewedCache = data
          .whereType<Map>()
          .map((e) => AlbumBrief.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return List.of(_viewedCache!);
    } catch (_) {
      _viewedCache = [];
      return const [];
    }
  }

  /// 记录看过某专辑（已存在则移到顶部，与「最近观看置顶」的展示排序一致）。
  Future<void> add(AlbumBrief album) async {
    await list();
    _viewedCache!.removeWhere((e) => e.id == album.id);
    _viewedCache!.insert(0, album);
    await _writeHistory();
  }

  /// 批量移除阅读记录（连同章节进度，各一次写盘）。
  Future<void> removeMany(List<int> albumIds) async {
    await list();
    final ids = Set<int>.of(albumIds);
    _viewedCache!.removeWhere((e) => ids.contains(e.id));
    await _writeHistory();
    // 删记录即删进度：不残留 progress.json 中的孤儿条目。
    final json = await _readProgressMap();
    json.removeWhere((k, _) => ids.contains(int.tryParse(k)));
    await _writeProgress();
  }

  // ---- 看到哪章 ----

  /// 某专辑的章节进度；无记录返回 null。
  Future<int?> readProgress(int albumId) async {
    final json = await _readProgressMap();
    return json['$albumId'];
  }

  /// 保存某专辑的章节进度。
  Future<void> saveProgress(int albumId, int chapterId) async {
    final json = await _readProgressMap();
    json['$albumId'] = chapterId;
    await _writeProgress();
  }

  // ---- 内部 ----

  Future<void> _writeHistory() async {
    final file = AppPaths.history;
    await file.writeAsString(jsonEncode(_viewedCache!.map((e) => e.toJson()).toList()));
  }

  Future<Map<String, int>> _readProgressMap() async {
    if (_progressCache != null) return _progressCache!;
    final file = AppPaths.progress;
    if (!await file.exists()) return _progressCache = {};
    try {
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return _progressCache = data.map((k, v) => MapEntry(k, toInt(v)));
    } catch (_) {
      return _progressCache = {};
    }
  }

  Future<void> _writeProgress() async {
    final file = AppPaths.progress;
    await file.writeAsString(jsonEncode(_progressCache!));
  }
}
