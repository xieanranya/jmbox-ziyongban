import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jmbox/core/storage/app_paths.dart';
import 'package:jmbox/data/models/album.dart';
import 'package:jmbox/data/providers.dart';
import 'package:jmbox/data/repositories/bookshelf_repository.dart';
import 'package:jmbox/data/repositories/reading_history_repository.dart';
import 'package:jmbox/features/album_detail/album_detail_providers.dart';
import 'package:jmbox/features/bookshelf/bookshelf_providers.dart';
import 'package:jmbox/features/history/history_providers.dart';

void main() {
  late Directory tempDir;
  late BookshelfRepository bookshelf;
  late ReadingHistoryRepository history;
  late ProviderContainer container;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('jmbox_library_provider_test_');
    AppPaths.supportPath = tempDir.path;
    bookshelf = BookshelfRepository();
    history = ReadingHistoryRepository();
    await bookshelf.add(const AlbumBrief(id: 1, name: '书架', author: '甲'));
    await history.add(const AlbumBrief(id: 2, name: '历史', author: '乙'));
    await history.saveProgress(2, 202);
    container = ProviderContainer(
      overrides: [
        bookshelfRepositoryProvider.overrideWithValue(bookshelf),
        readingHistoryRepositoryProvider.overrideWithValue(history),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('书架状态加载并在批量删除后刷新', () async {
    expect((await container.read(bookshelfProvider.future)).single.id, 1);
    await container.read(bookshelfProvider.notifier).removeMany([1]);
    expect(container.read(bookshelfProvider).value, isEmpty);
  });

  test('阅读历史状态加载并在删除后刷新', () async {
    expect((await container.read(readingHistoryProvider.future)).single.id, 2);
    await container.read(readingHistoryProvider.notifier).removeMany([2]);
    expect(container.read(readingHistoryProvider).value, isEmpty);
    expect(await history.readProgress(2), isNull);
  });

  test('详情书架状态支持添加、判断和删除', () async {
    // 详情页与书架页共用全局 bookshelfProvider。
    await container.read(bookshelfProvider.future);
    const album = AlbumBrief(id: 3, name: '详情', author: '丙');
    await container.read(bookshelfProvider.notifier).add(album);
    expect(container.read(bookshelfProvider.notifier).contains(3), isTrue);
    await container.read(bookshelfProvider.notifier).removeMany([3]);
    expect(container.read(bookshelfProvider.notifier).contains(3), isFalse);
  });

  test('章节进度 Provider 返回仓库记录', () async {
    expect(await container.read(albumReadingProgressProvider(2).future), 202);
    expect(await container.read(albumReadingProgressProvider(999).future), isNull);
  });
}
