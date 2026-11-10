/// 阅读器解码图缓存：会话级 LRU + 引用计数。
///
/// 背景：原先每页滚出视口就 `dispose` 解码结果，向上回翻要重新「取字节 → 解码 →
/// 分块重排」（单页几十到上百毫秒，主 isolate），表现为翻回去时卡顿、闪白、手感生硬。
///
/// 约定：
/// - 图的**所有权归缓存**，widget 只借不还（拿到 [CachedImage] 用完调 [CachedImage.release]）。
/// - 只有「无人引用」的条目才会被淘汰/释放，杜绝 use-after-dispose。
/// - 同一 key 并发请求合并为一次解码。
library;

import 'dart:collection';
import 'dart:ui' as ui;

/// 缓存条目：解码图 + 引用计数 + 淘汰标记。
class _Entry {
  _Entry(this.image);

  final ui.Image image;

  /// 正在使用该图的 widget 数量。
  int refs = 0;

  /// 已被淘汰但因仍被引用而暂未 dispose；refs 归零时再释放。
  bool evicted = false;

  void acquire() => refs++;

  bool release() {
    if (refs > 0) refs--;
    return refs == 0 && evicted;
  }
}

/// 借给 widget 的图句柄。用完必须 [release]，否则缓存无法回收该图。
class CachedImage {
  CachedImage._(this._cache, this._key, this._entry) : image = _entry.image;

  final ReaderImageCache _cache;
  final String _key;
  final _Entry _entry;

  /// 解码后的图；生命周期由缓存管理，调用方**不要**自行 dispose。
  final ui.Image image;

  bool _released = false;

  /// 归还本次引用（幂等）。
  void release() {
    if (_released) return;
    _released = true;
    _cache._release(_key, _entry);
  }
}

/// 全局解码图缓存（阅读会话共享）。
class ReaderImageCache {
  ReaderImageCache._();

  static final ReaderImageCache instance = ReaderImageCache._();

  /// 最多保留多少张解码图：手机上可见 5 页上下 + 预取几页，10 张够用；
  /// 每张按屏宽解码约 1~4MB，再多会明显挤占内存。
  int maxEntries = 10;

  final LinkedHashMap<String, _Entry> _entries = LinkedHashMap<String, _Entry>();

  /// 解码中的请求：同一 key 并发请求共用一次解码。
  final Map<String, Future<ui.Image>> _inflight = {};

  /// 取图：命中则直接借用（refs+1）；未命中用 [loader] 解码后登记。
  ///
  /// [loader] 产出的图所有权交给缓存，调用方不要 dispose。
  Future<CachedImage> acquire(String key, Future<ui.Image> Function() loader) async {
    final hit = _entries.remove(key);
    if (hit != null) {
      _entries[key] = hit; // 重新插入 = 标记最近使用
      hit.acquire();
      return CachedImage._(this, key, hit);
    }

    var future = _inflight[key];
    if (future == null) {
      future = loader();
      _inflight[key] = future;
      future.then<void>((_) {}, onError: (Object _) {}).whenComplete(() {
        // 只清理自己登记的那次解码。
        if (identical(_inflight[key], future)) _inflight.remove(key);
      });
    }

    final image = await future;
    final existing = _entries[key];
    if (existing != null) {
      existing.acquire();
      return CachedImage._(this, key, existing);
    }
    final entry = _Entry(image)..acquire();
    _entries[key] = entry;
    _evictIfNeeded();
    return CachedImage._(this, key, entry);
  }

  /// 预取：解出来放进缓存但不持有引用；失败静默（真正翻到该页会再试）。
  Future<void> prefetch(String key, Future<ui.Image> Function() loader) async {
    if (_entries.containsKey(key) || _inflight.containsKey(key)) return;
    try {
      final cached = await acquire(key, loader);
      cached.release();
    } catch (_) {
      // 预取失败不影响阅读。
    }
  }

  /// 丢弃整章缓存（换章 / 退出阅读器）。
  void evictChapter(int chapterId) {
    final prefix = '$chapterId/';
    final keys = _entries.keys.where((k) => k.startsWith(prefix)).toList();
    for (final key in keys) {
      final entry = _entries.remove(key);
      if (entry == null) continue;
      if (entry.refs == 0) {
        entry.image.dispose();
      } else {
        entry.evicted = true;
      }
    }
  }

  /// 清空全部缓存（会话结束）。
  void clear() {
    for (final entry in _entries.values) {
      if (entry.refs == 0) {
        entry.image.dispose();
      } else {
        entry.evicted = true;
      }
    }
    _entries.clear();
    _inflight.clear();
  }

  void _release(String key, _Entry entry) {
    final current = _entries[key];
    if (!identical(current, entry)) {
      // 条目已被整章清理或替换：若已被标记淘汰，这里补一次释放。
      if (entry.release()) entry.image.dispose();
      return;
    }
    if (entry.release()) {
      _entries.remove(key);
      entry.image.dispose();
    }
  }

  /// 超容量时淘汰最久未用且无人引用的条目。
  void _evictIfNeeded() {
    if (_entries.length <= maxEntries) return;
    final removable = _entries.entries.where((e) => e.value.refs == 0).map((e) => e.key).toList();
    for (final key in removable) {
      if (_entries.length <= maxEntries) break;
      _entries.remove(key)?.image.dispose();
    }
  }
}
