import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jmbox/features/reader/page_geometry.dart';
import 'package:jmbox/features/reader/widgets/reader_page_image.dart';

final Uint8List _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
  'AAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

ReaderPageImage _image({
  required String imageName,
  required PageGeometry geometry,
  required Future<Uint8List> Function(int, String) readPhoto,
}) => ReaderPageImage(
  chapterId: 100,
  imageName: imageName,
  index: 0,
  geometry: geometry,
  viewportWidth: 200,
  readPhoto: readPhoto,
  scrambleOf: (_) async => 999999,
);

void main() {
  testWidgets('快速命中缓存时直接显示图片并回填真实比例', (tester) async {
    final geometry = PageGeometry();
    await tester.pumpWidget(
      _wrap(_image(imageName: '1.png', geometry: geometry, readPhoto: (_, _) async => _pngBytes)),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();

    expect(find.byType(RawImage), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(geometry.aspectOf(0), closeTo(1.0, 1e-9));
  });

  testWidgets('慢请求在延迟后才显示进度提示', (tester) async {
    final completer = Completer<Uint8List>();
    await tester.pumpWidget(
      _wrap(
        _image(
          imageName: 'slow.png',
          geometry: PageGeometry(),
          readPhoto: (_, _) => completer.future,
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pump(const Duration(milliseconds: 179));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pump(const Duration(milliseconds: 2));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(_pngBytes);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    expect(find.byType(RawImage), findsOneWidget);
  });

  testWidgets('切换图片会重新计算转圈延迟，避免立即灰闪', (tester) async {
    final first = Completer<Uint8List>();
    final second = Completer<Uint8List>();
    final geometry = PageGeometry();

    await tester.pumpWidget(
      _wrap(_image(imageName: 'first.png', geometry: geometry, readPhoto: (_, _) => first.future)),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpWidget(
      _wrap(
        _image(imageName: 'second.png', geometry: geometry, readPhoto: (_, _) => second.future),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);

    first.complete(_pngBytes);
    second.complete(_pngBytes);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
  });

  testWidgets('失败态可点击重试并恢复显示', (tester) async {
    var attempts = 0;
    Future<Uint8List> readPhoto(int _, String _) async {
      attempts++;
      if (attempts == 1) throw StateError('failed once');
      return _pngBytes;
    }

    await tester.pumpWidget(
      _wrap(_image(imageName: 'retry.png', geometry: PageGeometry(), readPhoto: readPhoto)),
    );
    await tester.pumpAndSettle();
    expect(find.text('第 1 页加载失败，点击重试'), findsOneWidget);

    await tester.tap(find.text('第 1 页加载失败，点击重试'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    expect(attempts, 2);
    expect(find.byType(RawImage), findsOneWidget);
  });
}
