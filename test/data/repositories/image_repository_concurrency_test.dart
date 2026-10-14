import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jmbox/core/storage/app_paths.dart';
import 'package:jmbox/data/repositories/image_repository.dart';

void main() {
  late Directory tempDir;
  late HttpServer server;
  late StreamSubscription<HttpRequest> subscription;
  late String baseUrl;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('jmbox_image_repository_test_');
    AppPaths.supportPath = tempDir.path;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://${server.address.address}:${server.port}';
  });

  tearDown(() async {
    await subscription.cancel();
    await server.close(force: true);
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('同一图片的并发缓存未命中只发起一次下载', () async {
    var requests = 0;
    subscription = server.listen((request) async {
      requests++;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      request.response.add([1, 2, 3]);
      await request.response.close();
    });
    final repository = ImageRepository(() => baseUrl, concurrency: 10);

    final files = await Future.wait([
      repository.getCover('same.jpg'),
      repository.getCover('same.jpg'),
      repository.getCover('same.jpg'),
    ]);

    expect(files.map((file) => file.path).toSet(), hasLength(1));
    expect(await files.first.readAsBytes(), [1, 2, 3]);
    expect(requests, 1);
  });

  test('下载失败会释放同 key 的 in-flight，后续调用可以重试', () async {
    var requests = 0;
    var shouldFail = true;
    subscription = server.listen((request) async {
      requests++;
      if (shouldFail) {
        request.response.statusCode = HttpStatus.badRequest;
      } else {
        request.response.add([4, 5, 6]);
      }
      await request.response.close();
    });
    final repository = ImageRepository(() => baseUrl);

    await expectLater(repository.getCover('retry.jpg'), throwsException);
    shouldFail = false;
    final file = await repository.getCover('retry.jpg');

    expect(await file.readAsBytes(), [4, 5, 6]);
    expect(requests, 2);
  });
}
