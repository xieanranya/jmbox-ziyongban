/// 阅读器「状态 + 决策 + 会话缓存」控制器：页面流状态、预取、预热、章节/scramble 缓存。
///
/// 不 import material / riverpod：滚动经 [requestScroll] 交还宿主，取数经 [ReaderDataSource] 注入；
/// 章节与 scramble 各持一张会话级 memo 表、随 dispose 释放（缓存生命周期即会话）。
/// 页面流纯计算为本文件末尾的库私有顶层函数。
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/constants/reader_config.dart';
import '../../data/models/album.dart';

/// 阅读器数据源：控制器对外的取数契约，宿主用仓库实现注入。
///
/// 控制器不感知 Riverpod / 仓库类型，只经此抽象取数，测试可传内存实现。
abstract class ReaderDataSource {
  /// 拉取某章元数据（含 images 与 series）。
  Future<Chapter> fetchChapter(int chapterId);

  /// 拉取某章 scramble id（分块还原阈值）。
  Future<int> fetchScrambleId(int chapterId);

  /// 读取某页图片文件（命中磁盘缓存则秒回）：预取只需落盘，单页显示再转字节。
  Future<File> readPhoto(int chapterId, String imageName);

  /// 保存某专辑的阅读进度（看到哪章）。
  Future<void> saveProgress(int albumId, int chapterId);
}

/// 阅读器页面流状态机 + 会话级数据缓存。数据副作用经 [ReaderDataSource] 注入，
/// 不感知 Riverpod / BuildContext；章节与 scramble 各持一张 memo 表，随控制器 dispose 释放。
class ReaderController extends ChangeNotifier {
  ReaderController({
    required this._dataSource,
    this.albumId,
    required int initialChapterId,
    this.requestScroll,
  }) : _initialChapterId = initialChapterId,
       _chapterId = initialChapterId {
    // 初始章异步加载：就绪后在 [_loadCurrentChapter] 的回调里填充章节列表并预热邻章。
    _loadCurrentChapter();
  }

  /// 取数契约：由宿主用仓库实现注入，控制器只经此抽象取数，不感知 Riverpod。
  final ReaderDataSource _dataSource;

  /// 所属专辑 id（可空）：由路由携带注入，用于章级阅读进度保存；缺失时跳过保存。
  final int? albumId;

  /// 进入阅读器时的初始章 id：首帧据此加载并解析章节列表。
  final int _initialChapterId;

  /// 定位初始章节下标；找不到回退第一章。
  static int _initialIndex(List<Series> chapters, int initialChapterId) {
    final idx = chapters.indexWhere((c) => c.id == initialChapterId);
    return idx >= 0 ? idx : 0;
  }

  /// 全部章节（已按 sort 升序）：初始章加载就绪后填充，会话内不变。未就绪时为空。
  List<Series> chapters = const [];

  /// 宿主执行滚动落位（跳页/Slider 松手时调用）；未提供时仅更新页码。
  final void Function(int targetPage)? requestScroll;

  int _chapterIndex = 0;

  /// 当前章 id：始终有效（构造期即置为初始章），不依赖 [chapters] 是否就绪。
  int _chapterId;

  /// 章节列表是否已由初始章解析填充（仅首帧一次）。
  bool _chaptersReady = false;

  /// 当前章已解析的数据（images 来源）；加载中或出错为 null。
  Chapter? _currentChapter;

  /// 当前章加载错误；无错误为 null。
  Object? _currentChapterError;

  int _currentPage = 0;

  /// 控制栏是否可见（点击画面切换）。
  bool _controlsVisible = true;

  /// Slider 拖拽期间的草稿值；null 表示未拖拽，Slider 跟随 [currentPage]。
  double? _sliderDraft;

  /// 已发起磁盘预取的页（key=chapterId-index），避免同一页重复排队下载。
  final Set<String> _prefetched = {};

  /// 会话级章节缓存：chapterId → Future。memo 去重，随控制器 dispose 释放。
  final Map<int, Future<Chapter>> _chapterCache = {};

  /// 会话级 scramble 缓存：chapterId → Future。多页共享一次解析，随控制器 dispose 释放。
  final Map<int, Future<int>> _scrambleCache = {};

  bool _disposed = false;

  // ---- 只读状态（供 UI） ----

  /// 当前章元数据。仅在加载完成且无错误时有效（宿主 data 分支访问）。
  Series get chapter => chapters[_chapterIndex];

  int get chapterIndex => _chapterIndex;

  /// 当前章 id（始终有效）。
  int get chapterId => _chapterId;

  /// 当前页（0 基）。
  int get currentPage => _currentPage;

  bool get controlsVisible => _controlsVisible;

  /// Slider 草稿值（null = 未拖拽）。
  double? get sliderDraft => _sliderDraft;

  /// 当前章已解析数据（images 来源）；加载中/出错为 null。
  Chapter? get currentChapter => _currentChapter;

  /// 当前章加载错误；无错误为 null。
  Object? get currentChapterError => _currentChapterError;

  /// 当前章是否加载中（无数据且无错误）。
  bool get isLoading => _currentChapter == null && _currentChapterError == null;

  /// 当前章总页数（数据未就绪时为 0）。
  int get pageCount => _currentChapter?.images.length ?? 0;

  // ---- 事件入口（由 State/Widget 转发） ----

  /// 可视位置变化 → 更新当前页。仅在页码真正变化时 notify，避免每帧重建。
  void updateFromPositions(Iterable<({int index, double leading, double trailing})> positions) {
    if (_disposed) return;
    final page = _currentPageFromPositions(positions);
    if (page == _currentPage) return;
    _currentPage = page;
    notifyListeners();
    _prefetchImages(page);
  }

  /// 点击画面：切换控制栏显隐。
  void toggleControls() {
    if (_disposed) return;
    _controlsVisible = !_controlsVisible;
    notifyListeners();
  }

  /// 跳到指定页：先同步推页码（防 Slider 滑回），再交宿主滚动。
  void jumpToPage(int index) {
    if (_disposed) return;
    final images = _currentChapter?.images;
    if (images == null || images.isEmpty) return;
    final target = index.clamp(0, images.length - 1);
    _currentPage = target;
    notifyListeners();
    _prefetchImages(target);
    requestScroll?.call(target);
  }

  /// 切换章节：重置页码与草稿（列表 key 变化会重建 ScrollablePositionedList）。
  void selectChapter(int index) {
    if (_disposed) return;
    if (index < 0 || index >= chapters.length) return;
    if (index == _chapterIndex) return;
    _chapterIndex = index;
    _chapterId = chapters[index].id;
    _currentPage = 0;
    _sliderDraft = null;
    // 换章即重载当前章数据（[_loadCurrentChapter] 内部 notify 驱动宿主刷新）。
    _loadCurrentChapter();
    _warmNeighborChapters();
  }

  /// 上一章（越界无操作）。
  void selectPreviousChapter() => selectChapter(_chapterIndex - 1);

  /// 下一章（越界无操作）。
  void selectNextChapter() => selectChapter(_chapterIndex + 1);

  /// Slider 拖拽中：仅记录草稿值，不动列表（避免边拖边滚导致落点漂移）。
  void onSliderChanged(double value) {
    if (_disposed) return;
    _sliderDraft = value;
    notifyListeners();
  }

  /// Slider 松手：按草稿跳页，随后清空草稿让 Slider 回落到真实当前页。
  void onSliderEnd() {
    if (_disposed) return;
    final draft = _sliderDraft;
    if (draft != null) {
      jumpToPage(_pageFromSlider(draft, pageCount));
    }
    _sliderDraft = null;
    notifyListeners();
  }

  // ---- 内部：预取与预热 ----

  /// 预取窗口内的图片到磁盘：命中缓存的页秒回，未命中的排队下载。
  void _prefetchImages(int center) {
    final images = _currentChapter?.images;
    if (images == null || images.isEmpty) return;
    final window = _prefetchWindow(
      center: center,
      ahead: kReaderPrefetchAhead,
      behind: kReaderPrefetchBehind,
      pageCount: images.length,
    );
    final chapterId = _chapterId;
    for (final index in window) {
      final key = '$chapterId-$index';
      if (!_prefetched.add(key)) continue; // 已发起过，跳过。
      unawaited(_prefetchOne(chapterId, images[index], key));
    }
  }

  /// 预取单页：失败静默并撤销去重标记，允许后续重试。
  Future<void> _prefetchOne(int chapterId, String imageName, String key) async {
    try {
      await _dataSource.readPhoto(chapterId, imageName);
    } catch (_) {
      _prefetched.remove(key);
    }
  }

  /// 进入某章即预热前后相邻章元数据，使切章落地即有页码不转圈。
  /// 相邻章走 [_chapter] memo，重复预热命中同一 Future 不重拉。
  void _warmNeighborChapters() {
    if (_chapterIndex > 0) _chapter(chapters[_chapterIndex - 1].id);
    if (_chapterIndex < chapters.length - 1) _chapter(chapters[_chapterIndex + 1].id);
  }

  // ---- 会话级数据缓存（memo）----

  /// 某章数据的 memo Future：首次触发加载，之后复用；失败即从缓存剔除以便重试。
  Future<Chapter> _chapter(int chapterId) {
    return _chapterCache.putIfAbsent(chapterId, () {
      final future = _dataSource.fetchChapter(chapterId);
      // 挂一个错误监听：既避免无人 await 的预热 Future 抛未处理异常，又在失败时清缓存。
      future.then<void>(
        (_) {},
        onError: (Object _) {
          if (identical(_chapterCache[chapterId], future)) {
            _chapterCache.remove(chapterId);
          }
        },
      );
      return future;
    });
  }

  /// 某章 scramble 的 memo Future：多页共享一次解析；失败即剔除以便重试。
  Future<int> scramble(int chapterId) {
    return _scrambleCache.putIfAbsent(chapterId, () {
      final future = _dataSource.fetchScrambleId(chapterId);
      future.then<void>(
        (_) {},
        onError: (Object _) {
          if (identical(_scrambleCache[chapterId], future)) {
            _scrambleCache.remove(chapterId);
          }
        },
      );
      return future;
    });
  }

  /// 读取某页图片字节：取数据源文件后转字节（磁盘缓存由仓库跨会话持有，控制器不重复缓存）。
  Future<Uint8List> readPhoto(int chapterId, String imageName) async {
    final file = await _dataSource.readPhoto(chapterId, imageName);
    return file.readAsBytes();
  }

  // ---- 当前章加载状态机 ----

  /// 加载当前章：置为 loading 并 notify，就绪后填充数据（初始章顺带解析章节列表）。
  ///
  /// 竞态以 [_chapterId] 兜底：回调时若已切走或控制器已 dispose，丢弃结果。
  void _loadCurrentChapter() {
    final id = _chapterId;
    _currentChapter = null;
    _currentChapterError = null;
    notifyListeners();
    _chapter(id).then(
      (value) {
        if (_disposed || id != _chapterId) return;
        if (!_chaptersReady) {
          chapters = value.series;
          _chapterIndex = _initialIndex(chapters, _initialChapterId);
          _chaptersReady = true;
          _warmNeighborChapters();
        }
        _currentChapter = value;
        notifyListeners();
        // 章级进度：当前章就绪即记录（进入 / 换章都会走到这里）。
        _saveProgress();
      },
      onError: (Object error) {
        if (_disposed || id != _chapterId) return;
        _currentChapterError = error;
        notifyListeners();
      },
    );
  }

  /// 保存当前章阅读进度（章级）：[albumId] 缺失时跳过；失败静默，不打断阅读。
  void _saveProgress() {
    final album = albumId;
    if (album == null) return;
    unawaited(_dataSource.saveProgress(album, _chapterId).catchError((Object _) {}));
  }

  /// 重试当前章：剔除失败缓存后重新加载。
  void retryCurrentChapter() {
    if (_disposed) return;
    _chapterCache.remove(_chapterId);
    _loadCurrentChapter();
  }

  @override
  void dispose() {
    if (_disposed) return; // 幂等：宿主主动 dispose 后允许再次调用（如测试 tearDown）。
    _disposed = true;
    super.dispose();
  }
}

// ---- 页面流纯计算（无状态、无 IO；库私有，仅供本文件 ReaderController 调用） ----

/// 从可视 item 位置集合中选出「当前页」下标：取视口内可见高度最大的那一页。
/// [positions] 每项 (index, leading, trailing) 为相对视口的归一化偏移（0 起点、1 终点），
/// 可见区间 = [max(leading,0), min(trailing,1)]；空集合返回 0。
int _currentPageFromPositions(Iterable<({int index, double leading, double trailing})> positions) {
  var bestIndex = 0;
  var bestVisible = -1.0;
  var found = false;
  for (final p in positions) {
    final visible = math.min(p.trailing, 1.0) - math.max(p.leading, 0.0);
    if (visible <= 0) continue;
    if (!found || visible > bestVisible) {
      found = true;
      bestVisible = visible;
      bestIndex = p.index;
    }
  }
  return found ? bestIndex : 0;
}

/// Slider 值（0..pageCount-1 的浮点）→ 目标页下标；越界夹取，空列表返回 0。
int _pageFromSlider(double value, int pageCount) {
  if (pageCount <= 1) return 0;
  return value.round().clamp(0, pageCount - 1);
}

/// 图片预取窗口：以 [center] 为中心，向主方向（页码增大）取 [ahead] 页、反向取 [behind] 页。
/// 返回下标按「去程侧由近及远整段优先再补来路侧」排序，不含 center（当前页由 UI 自加载），
/// 越界与负索引自动剔除。
List<int> _prefetchWindow({
  required int center,
  required int ahead,
  required int behind,
  required int pageCount,
}) {
  if (pageCount <= 0) return const [];
  final c = center.clamp(0, pageCount - 1);
  final result = <int>[];
  // 先去程侧（c+1..c+ahead），再补来路侧（c-behind..c-1）；c 已夹取，各自单边判界即可。
  for (var d = 1; d <= ahead; d++) {
    final i = c + d;
    if (i < pageCount) result.add(i);
  }
  for (var d = 1; d <= behind; d++) {
    final i = c - d;
    if (i >= 0) result.add(i);
  }
  return result;
}
