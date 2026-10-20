import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jmbox/data/models/album.dart';
import 'package:jmbox/features/reader/reader_controller.dart';

List<Series> _catalog() => const [
  Series(id: 100, name: '第一话', sort: '1'),
  Series(id: 101, name: '第二话', sort: '2'),
  Series(id: 102, name: '第三话', sort: '3'),
];

class _FakeReaderDataSource implements ReaderDataSource {
  _FakeReaderDataSource(this.directory, {List<Series>? catalog}) : catalog = catalog ?? _catalog();

  final Directory directory;
  final List<Series> catalog;
  final Map<int, int> chapterFetches = {};
  final Map<int, int> scrambleFetches = {};
  final List<String> photoReads = [];
  final List<String> savedProgress = [];
  final Set<int> failingChapters = {};
  final Set<int> failingScrambles = {};
  final Set<String> failPhotoOnce = {};

  @override
  Future<Chapter> fetchChapter(int chapterId) async {
    chapterFetches.update(chapterId, (count) => count + 1, ifAbsent: () => 1);
    if (failingChapters.contains(chapterId)) throw StateError('chapter $chapterId failed');
    return Chapter(
      id: chapterId,
      series: catalog,
      images: [for (var i = 0; i < 10; i++) '$i.webp'],
    );
  }

  @override
  Future<int> fetchScrambleId(int chapterId) async {
    scrambleFetches.update(chapterId, (count) => count + 1, ifAbsent: () => 1);
    if (failingScrambles.contains(chapterId)) {
      throw StateError('scramble $chapterId failed');
    }
    return 220980 + chapterId;
  }

  @override
  Future<File> readPhoto(int chapterId, String imageName) async {
    final key = '$chapterId/$imageName';
    photoReads.add(key);
    if (failPhotoOnce.remove(key)) throw StateError('photo failed');
    return File('${directory.path}/photo.bin');
  }

  @override
  Future<void> saveProgress(int albumId, int chapterId) async {
    savedProgress.add('$albumId/$chapterId');
  }
}

Iterable<({int index, double leading, double trailing})> _at(int index) => [
  (index: index, leading: 0.0, trailing: 1.0),
];

void main() {
  late Directory tempDir;
  late _FakeReaderDataSource dataSource;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('jmbox_reader_test_');
    await File('${tempDir.path}/photo.bin').writeAsBytes([101, 6]);
    dataSource = _FakeReaderDataSource(tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  ReaderController createController({int initialChapterId = 101, int? albumId = 9}) {
    final controller = ReaderController(
      dataSource: dataSource,
      albumId: albumId,
      initialChapterId: initialChapterId,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  test('初始章加载后建立章节列表、预热相邻章并保存进度', () async {
    final controller = createController();
    expect(controller.isLoading, isTrue);

    await pumpEventQueue();

    expect(controller.currentChapter?.id, 101);
    expect(controller.chapterIndex, 1);
    expect(controller.chapter.name, '第二话');
    expect(controller.pageCount, 10);
    expect(dataSource.chapterFetches.keys, containsAll([100, 101, 102]));
    expect(dataSource.chapterFetches[101], 1);
    expect(dataSource.savedProgress, ['9/101']);
  });

  test('albumId 缺失时不保存进度', () async {
    createController(albumId: null);
    await pumpEventQueue();
    expect(dataSource.savedProgress, isEmpty);
  });

  test('可视面积最大的页面成为当前页并触发有序预取', () async {
    final controller = createController();
    await pumpEventQueue();
    controller.updateFromPositions([
      (index: 2, leading: -0.8, trailing: 0.2),
      (index: 3, leading: 0.2, trailing: 0.9),
    ]);
    await pumpEventQueue();

    expect(controller.currentPage, 3);
    expect(dataSource.photoReads, [
      '101/4.webp',
      '101/5.webp',
      '101/6.webp',
      '101/7.webp',
      '101/8.webp',
      '101/2.webp',
      '101/1.webp',
    ]);
  });

  test('重复覆盖同一预取窗口不会重复读取，失败页允许重试', () async {
    final controller = createController();
    await pumpEventQueue();
    dataSource.failPhotoOnce.add('101/4.webp');
    controller.updateFromPositions(_at(3));
    await pumpEventQueue();
    controller.updateFromPositions(_at(5));
    await pumpEventQueue();

    expect(dataSource.photoReads.where((key) => key == '101/4.webp'), hasLength(2));
    expect(dataSource.photoReads.where((key) => key == '101/6.webp'), hasLength(1));
  });

  test('跳页夹取边界，Slider 松手才真正跳页', () async {
    final scrolled = <int>[];
    final controller = ReaderController(
      dataSource: dataSource,
      albumId: 9,
      initialChapterId: 101,
      requestScroll: scrolled.add,
    );
    addTearDown(controller.dispose);
    await pumpEventQueue();

    controller.jumpToPage(99);
    expect(controller.currentPage, 9);
    expect(scrolled, [9]);
    controller.onSliderChanged(3.6);
    expect(controller.currentPage, 9);
    expect(controller.sliderDraft, 3.6);
    controller.onSliderEnd();
    expect(controller.currentPage, 4);
    expect(controller.sliderDraft, isNull);
    expect(scrolled, [9, 4]);
  });

  test('切章重置页面草稿、复用预热缓存并保存新进度', () async {
    final controller = createController();
    await pumpEventQueue();
    controller.jumpToPage(8);
    controller.onSliderChanged(4);
    controller.selectNextChapter();
    await pumpEventQueue();

    expect(controller.chapterId, 102);
    expect(controller.chapterIndex, 2);
    expect(controller.currentPage, 0);
    expect(controller.sliderDraft, isNull);
    expect(controller.currentChapter?.id, 102);
    expect(dataSource.chapterFetches[102], 1);
    expect(dataSource.savedProgress, ['9/101', '9/102']);
  });

  test('章节失败进入错误态，重试后恢复', () async {
    dataSource.failingChapters.add(101);
    final controller = createController();
    await pumpEventQueue();
    expect(controller.currentChapterError, isA<StateError>());
    expect(controller.isLoading, isFalse);

    dataSource.failingChapters.remove(101);
    controller.retryCurrentChapter();
    expect(controller.isLoading, isTrue);
    await pumpEventQueue();
    expect(controller.currentChapter?.id, 101);
    expect(controller.currentChapterError, isNull);
    expect(dataSource.chapterFetches[101], 2);
  });

  test('scramble 同章并发请求复用 Future，读图返回文件字节', () async {
    final controller = createController();
    await pumpEventQueue();
    final values = await Future.wait([controller.scramble(101), controller.scramble(101)]);
    expect(values, [221081, 221081]);
    expect(dataSource.scrambleFetches[101], 1);
    expect(await controller.readPhoto(101, 'x.webp'), [101, 6]);
  });

  test('scramble 失败会清除 memo，后续请求可重新获取', () async {
    final controller = createController();
    await pumpEventQueue();
    dataSource.failingScrambles.add(101);
    await expectLater(controller.scramble(101), throwsStateError);
    dataSource.failingScrambles.remove(101);

    expect(await controller.scramble(101), 221081);
    expect(dataSource.scrambleFetches[101], 2);
  });

  test('控制栏切换会通知，dispose 后事件入口全部忽略', () async {
    final controller = createController();
    await pumpEventQueue();
    var notifications = 0;
    controller.addListener(() => notifications++);
    controller.toggleControls();
    expect(controller.controlsVisible, isFalse);
    expect(notifications, 1);

    controller.dispose();
    controller.toggleControls();
    controller.jumpToPage(5);
    controller.updateFromPositions(_at(5));
    expect(controller.controlsVisible, isFalse);
    expect(controller.currentPage, 0);
    expect(notifications, 1);
  });
}
