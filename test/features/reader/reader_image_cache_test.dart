/// 阅读器解码图缓存单测：共享解码、引用计数、LRU 淘汰、按章清理。
///
/// 这些不变量直接决定阅读器滚动的稳定性：
/// - 同一页并发请求只能解码一次（否则滚动时重复解码、暴卡）
/// - 正在显示的图不能被淘汰释放（否则 use-after-dispose 崩溃）
/// - 换章要能整章丢弃（否则串章吃内存）
library;

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:jmbox/features/reader/reader_image_cache.dart';

/// 造一张 2x2 的纯色图。
Future<ui.Image> _makeImage() {
  final pixels = Uint8List(2 * 2 * 4)..fillRange(0, 16, 128);
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(pixels, 2, 2, ui.PixelFormat.rgba8888, completer.complete);
  return completer.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReaderImageCache cache;

  setUp(() {
    cache = ReaderImageCache.instance;
    cache.clear();
    cache.maxEntries = 10;
  });

  tearDown(() => cache.clear());

  test('同一 key 并发请求只解码一次', () async {
    var decodes = 0;
    Future<ui.Image> loader() async {
      decodes++;
      return _makeImage();
    }

    final results = await Future.wait([
      cache.acquire('1/a@100', loader),
      cache.acquire('1/a@100', loader),
      cache.acquire('1/a@100', loader),
    ]);

    expect(decodes, 1, reason: '并发请求应合并为一次解码');
    expect(results.map((r) => r.image).toSet().length, 1, reason: '应共享同一张图');
    for (final r in results) {
      r.release();
    }
  });

  test('释放后再次借用命中缓存，不再解码', () async {
    var decodes = 0;
    Future<ui.Image> loader() async {
      decodes++;
      return _makeImage();
    }

    final first = await cache.acquire('1/a@100', loader);
    first.release();
    final second = await cache.acquire('1/a@100', loader);
    second.release();

    expect(decodes, 1, reason: '第二次应命中缓存');
  });

  test('超出容量时淘汰无人引用条目（最久未用先走）', () async {
    cache.maxEntries = 2;
    final handles = <CachedImage>[];
    for (var i = 0; i < 4; i++) {
      final h = await cache.acquire('1/p$i@100', _makeImage);
      h.release(); // 都不持有引用
      handles.add(h);
    }
    // 再借一次 p0：已被淘汰，必须重新解码（会调用 loader）
    var redecoded = false;
    final again = await cache.acquire('1/p0@100', () async {
      redecoded = true;
      return _makeImage();
    });
    again.release();

    expect(redecoded, isTrue, reason: '最久未用条目应已被淘汰');
  });

  test('仍被引用的条目不会被淘汰', () async {
    cache.maxEntries = 1;
    final held = await cache.acquire('1/keep@100', _makeImage);

    // 再塞入三张，容量 1，但 keep 仍被引用，不能释放
    for (var i = 0; i < 3; i++) {
      final h = await cache.acquire('1/other$i@100', _makeImage);
      h.release();
    }

    expect(held.image.debugDisposed, isFalse, reason: '持有引用的图不能被释放');

    var redecoded = false;
    final again = await cache.acquire('1/keep@100', () async {
      redecoded = true;
      return _makeImage();
    });
    again.release();
    held.release();

    expect(redecoded, isFalse, reason: '被引用的条目应仍在缓存中');
  });

  test('按章清理：整章条目失效', () async {
    final a = await cache.acquire('7/x@100', _makeImage);
    a.release();
    final b = await cache.acquire('8/y@100', _makeImage);
    b.release();

    cache.evictChapter(7);

    var redecoded = false;
    final again = await cache.acquire('7/x@100', () async {
      redecoded = true;
      return _makeImage();
    });
    again.release();
    expect(redecoded, isTrue, reason: '被清理的章需要重新解码');

    var chapter8Redecoded = false;
    final still = await cache.acquire('8/y@100', () async {
      chapter8Redecoded = true;
      return _makeImage();
    });
    still.release();
    expect(chapter8Redecoded, isFalse, reason: '其他章不受影响');
  });

  test('预取失败不影响后续正常取图', () async {
    await cache.prefetch('1/bad@100', () => Future<ui.Image>.error(StateError('boom')));
    final ok = await cache.acquire('1/bad@100', _makeImage);
    ok.release();
    expect(ok.image.width, 2);
  });
}
