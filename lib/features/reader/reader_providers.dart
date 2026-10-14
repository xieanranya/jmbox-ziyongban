/// 阅读器装配 Provider：把仓库组装成控制器用的 [ReaderDataSource]。
///
/// 只承载「依赖组装」，不承载任何缓存：[ReaderDataSource] 是无状态装配器，keepAlive 常驻也零内存增长。
/// 章节/scramble 缓存归 [ReaderController] 的会话级 memo 表，随控制器 dispose 释放。
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/album.dart';
import '../../data/providers.dart';
import '../../data/repositories/api_repository.dart';
import '../../data/repositories/image_repository.dart';
import '../../data/repositories/reading_history_repository.dart';
import 'reader_controller.dart';

/// 阅读器数据源：约束控制器只能用到这三个取数动作，隔离仓库的完整 API 面。
/// 宿主在 initState 经 `ref.read` 取一次注入 [ReaderController]；此后控制器只经此实例取数，
/// 不感知 Riverpod。测试直接传内存实现。
final readerDataSourceProvider = Provider<ReaderDataSource>((ref) {
  return _RepositoryReaderDataSource(
    ref.watch(apiRepositoryProvider),
    ref.watch(imageRepositoryProvider),
    ref.watch(readingHistoryRepositoryProvider),
  );
});

/// 用仓库实现 [ReaderDataSource]。
class _RepositoryReaderDataSource implements ReaderDataSource {
  _RepositoryReaderDataSource(this._api, this._images, this._history);

  final ApiRepository _api;
  final ImageRepository _images;
  final ReadingHistoryRepository _history;

  @override
  Future<Chapter> fetchChapter(int chapterId) => _api.getChapter(chapterId);

  @override
  Future<int> fetchScrambleId(int chapterId) => _api.getScrambleId(chapterId);

  @override
  Future<File> readPhoto(int chapterId, String imageName) => _images.getPhoto(chapterId, imageName);

  @override
  Future<void> saveProgress(int albumId, int chapterId) =>
      _history.saveProgress(albumId, chapterId);
}
