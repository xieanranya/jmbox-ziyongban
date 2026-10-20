import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jmbox/core/constants/theme.dart';
import 'package:jmbox/core/storage/app_paths.dart';
import 'package:jmbox/data/models/album.dart';
import 'package:jmbox/data/repositories/bookshelf_repository.dart';
import 'package:jmbox/data/repositories/config_repository.dart';
import 'package:jmbox/data/repositories/image_repository.dart';
import 'package:jmbox/data/repositories/reading_history_repository.dart';
import 'package:jmbox/data/repositories/search_history_repository.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('jmbox_repository_test_');
    AppPaths.supportPath = tempDir.path;
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('ConfigRepository', () {
    test('首次读取写入默认配置并缓存同一对象', () {
      final repository = ConfigRepository();
      final first = repository.read();
      final second = repository.read();
      expect(identical(first, second), isTrue);
      expect(first.username, isEmpty);
      expect(first.imageAuto, isTrue);
      expect(first.themeSetting, ThemeSetting.system);
      expect(AppPaths.config.existsSync(), isTrue);
    });

    test('updateWith 保留未指定字段、支持清空密码并持久化', () {
      final repository = ConfigRepository();
      repository.updateWith(
        username: 'alice',
        password: 'secret',
        apiHost: 'https://api.test',
        themeSetting: ThemeSetting.dark,
      );
      repository.updateWith(password: '', autoCheckin: true);

      final reloaded = ConfigRepository().read();
      expect(reloaded.username, 'alice');
      expect(reloaded.password, '');
      expect(reloaded.apiHost, 'https://api.test');
      expect(reloaded.autoCheckin, isTrue);
      expect(reloaded.themeSetting, ThemeSetting.dark);
    });

    test('损坏配置回退默认值且不向调用方抛异常', () {
      AppPaths.config.writeAsStringSync('{broken');
      final config = ConfigRepository().read();
      expect(config.username, isEmpty);
      expect(config.themeSetting, ThemeSetting.system);
    });
  });

  group('BookshelfRepository', () {
    test('新增置顶、重复新增更新摘要并可批量删除', () async {
      final repository = BookshelfRepository();
      const a = AlbumBrief(id: 1, name: 'A', author: '甲');
      const b = AlbumBrief(id: 2, name: 'B', author: '乙');
      await repository.add(a);
      await repository.add(b);
      await repository.add(const AlbumBrief(id: 1, name: 'A2', author: '新作者'));

      expect((await repository.list()).map((item) => item.id), [1, 2]);
      expect((await repository.list()).first.name, 'A2');
      expect(await repository.contains(2), isTrue);

      await repository.removeMany([1, 999]);
      expect((await repository.list()).map((item) => item.id), [2]);
    });

    test('返回防御性副本并可由新实例从磁盘恢复', () async {
      await BookshelfRepository().add(const AlbumBrief(id: 1, name: 'A', author: '甲'));
      final repository = BookshelfRepository();
      final external = await repository.list();
      external.clear();
      expect(await repository.list(), hasLength(1));
      expect((await BookshelfRepository().list()).single.id, 1);
    });

    test('损坏文件回退空列表', () async {
      await AppPaths.bookshelf.writeAsString('{broken');
      expect(await BookshelfRepository().list(), isEmpty);
    });
  });

  group('ReadingHistoryRepository', () {
    test('最近观看置顶并持久化章节进度', () async {
      final repository = ReadingHistoryRepository();
      await repository.add(const AlbumBrief(id: 1, name: 'A', author: '甲'));
      await repository.add(const AlbumBrief(id: 2, name: 'B', author: '乙'));
      await repository.add(const AlbumBrief(id: 1, name: 'A2', author: '新作者'));
      await repository.saveProgress(1, 101);
      await repository.saveProgress(2, 202);

      expect((await repository.list()).map((item) => item.id), [1, 2]);
      expect((await repository.list()).first.name, 'A2');
      expect(await ReadingHistoryRepository().readProgress(1), 101);
    });

    test('删除观看记录同时删除对应进度且保留其他进度', () async {
      final repository = ReadingHistoryRepository();
      await repository.add(const AlbumBrief(id: 1, name: 'A', author: '甲'));
      await repository.add(const AlbumBrief(id: 2, name: 'B', author: '乙'));
      await repository.saveProgress(1, 101);
      await repository.saveProgress(2, 202);
      await repository.removeMany([1]);

      expect((await repository.list()).map((item) => item.id), [2]);
      expect(await repository.readProgress(1), isNull);
      expect(await repository.readProgress(2), 202);
    });

    test('损坏历史与进度文件分别回退为空', () async {
      await AppPaths.history.writeAsString('{broken');
      await AppPaths.progress.writeAsString('[broken]');
      final repository = ReadingHistoryRepository();
      expect(await repository.list(), isEmpty);
      expect(await repository.readProgress(1), isNull);
    });

    test('首次从磁盘返回的观看列表也是防御性副本', () async {
      await ReadingHistoryRepository().add(const AlbumBrief(id: 1, name: 'A', author: '甲'));
      final repository = ReadingHistoryRepository();
      final external = await repository.list();
      external.clear();
      expect(await repository.list(), hasLength(1));
    });
  });

  group('SearchHistoryRepository', () {
    test('忽略空词、去重置顶并支持删除与清空', () async {
      final repository = SearchHistoryRepository();
      await repository.add('  ');
      await repository.add(' 原神 ');
      await repository.add('火影');
      await repository.add('原神');
      expect(await repository.list(), ['原神', '火影']);
      await repository.remove('火影');
      expect(await repository.list(), ['原神']);
      await repository.clear();
      expect(await repository.list(), isEmpty);
    });

    test('只保留最近 20 条并持久化', () async {
      final repository = SearchHistoryRepository();
      for (var i = 0; i < 25; i++) {
        await repository.add('关键词$i');
      }
      final items = await SearchHistoryRepository().list();
      expect(items, hasLength(20));
      expect(items.first, '关键词24');
      expect(items.last, '关键词5');
    });

    test('过滤非字符串成员且返回防御性副本', () async {
      await AppPaths.searchHistory.writeAsString(jsonEncode(['A', 1, 'B']));
      final repository = SearchHistoryRepository();
      final external = await repository.list();
      expect(external, ['A', 'B']);
      external.clear();
      expect(await repository.list(), ['A', 'B']);
    });
  });

  group('ImageRepository 缓存维护', () {
    test('已缓存文件无需网络即可返回', () async {
      final file = File('${AppPaths.images.path}/covers/a.jpg');
      await file.create(recursive: true);
      await file.writeAsBytes([1, 2, 3]);
      final repository = ImageRepository(() => null);
      expect((await repository.getCover('a.jpg')).path, file.path);
    });

    test('统计递归文件总大小并清空缓存目录', () async {
      final first = File('${AppPaths.images.path}/covers/a.jpg');
      final second = File('${AppPaths.images.path}/photos/1/b.jpg');
      await first.create(recursive: true);
      await second.create(recursive: true);
      await first.writeAsBytes([1, 2, 3]);
      await second.writeAsBytes([4, 5]);
      final repository = ImageRepository(() => null);
      expect(await repository.totalSize(), 5);
      await repository.clearCache();
      expect(await repository.totalSize(), 0);
    });
  });
}
