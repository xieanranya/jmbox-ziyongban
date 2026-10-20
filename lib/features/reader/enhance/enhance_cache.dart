/// 增强结果内存缓存（LRU）：key = `章节id/图片名@档位`。
///
/// 所有权约定（重要）：缓存是增强图的**唯一持有者**——widget 只借不还：
/// - 淘汰时**不 dispose**（图可能正被某个 widget 绘制，交给 GC/引擎回收）；
/// - 原图（未增强）由 widget 独占持有，照旧 dispose。
/// 这样避免「淘汰掉正在显示的图」崩溃，代价是上限内的常驻显存。
library;

import 'dart:collection';
import 'dart:ui' as ui;

class EnhanceImageCache {
  EnhanceImageCache({this.maxCount = 16, this.maxBytes = 128 * 1024 * 1024});

  /// 最多缓存几张增强图。
  final int maxCount;

  /// 缓存像素字节上限（近似值，含少量管理开销）。
  final int maxBytes;

  final LinkedHashMap<String, ui.Image> _entries = LinkedHashMap();
  int _bytes = 0;

  /// 取图并刷新 LRU 次序；未命中返回 null。
  ui.Image? get(String key) {
    final image = _entries.remove(key);
    if (image == null) return null;
    _entries[key] = image;
    return image;
  }

  /// 存入（同 key 覆盖，旧图直接丢弃不 dispose——理由见库注释）。
  void put(String key, ui.Image image) {
    final old = _entries.remove(key);
    if (old != null) _bytes -= _sizeOf(old);
    _entries[key] = image;
    _bytes += _sizeOf(image);
    _evictIfNeeded();
  }

  void _evictIfNeeded() {
    while (_entries.isNotEmpty && (_entries.length > maxCount || _bytes > maxBytes)) {
      final victim = _entries.remove(_entries.keys.first);
      if (victim == null) break;
      _bytes -= _sizeOf(victim);
    }
  }

  int _sizeOf(ui.Image image) => image.width * image.height * 4 + 64;

  /// 丢弃某章的全部增强图（换章/退出阅读器时释放显存）。
  void evictChapter(int chapterId) {
    final prefix = '$chapterId/';
    final keys = _entries.keys.where((k) => k.startsWith(prefix)).toList();
    for (final key in keys) {
      final image = _entries.remove(key);
      if (image != null) _bytes -= _sizeOf(image);
    }
  }

  void clear() {
    _entries.clear();
    _bytes = 0;
  }
}
