import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jmbox/core/constants/app_constants.dart';
import 'package:jmbox/core/constants/sort.dart';
import 'package:jmbox/core/network/api_client.dart';
import 'package:jmbox/core/network/exception.dart';
import 'package:jmbox/data/repositories/api_repository.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/ecb.dart';
import 'package:pointycastle/padded_block_cipher/padded_block_cipher_impl.dart';
import 'package:pointycastle/paddings/pkcs7.dart';

String _encryptForRequest(HttpRequest request, Object payload) {
  final tokenParam = request.headers.value('Tokenparam');
  final time = int.parse(tokenParam!.split(',').first);
  final keyHex = md5.convert(utf8.encode('$time$kAppDataSecret')).toString();
  final cipher = PaddedBlockCipherImpl(PKCS7Padding(), ECBBlockCipher(AESEngine()))
    ..init(
      true,
      PaddedBlockCipherParameters<KeyParameter, Null>(
        KeyParameter(Uint8List.fromList(utf8.encode(keyHex))),
        null,
      ),
    );
  final plain = Uint8List.fromList(utf8.encode(jsonEncode(payload)));
  return base64Encode(cipher.process(plain));
}

Future<void> _replyData(HttpRequest request, Object payload) async {
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode({'code': 200, 'data': _encryptForRequest(request, payload)}));
  await request.response.close();
}

Future<void> _replyError(HttpRequest request, int statusCode, String message) async {
  request.response.statusCode = statusCode;
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode({'errorMsg': message}));
  await request.response.close();
}

Map<String, dynamic> _albumPayload({int id = 42, List<Map<String, dynamic>>? series}) => {
  'id': id,
  'name': '测试专辑$id',
  'author': ['作者甲', '作者乙'],
  'description': '简介',
  'tags': ['剧情'],
  'total_photos': 2,
  'addtime': '1700000000',
  'total_views': 10,
  'likes': 3,
  'series': series ?? const [],
  'comment_total': 1,
  'liked': false,
  'is_favorite': false,
};

void main() {
  late HttpServer server;
  late StreamSubscription<HttpRequest> subscription;
  late Future<void> Function(HttpRequest request) handler;
  late String baseUrl;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://${server.address.address}:${server.port}';
    handler = (request) => _replyData(request, const {});
    subscription = server.listen((request) async {
      try {
        await handler(request);
      } catch (error, stackTrace) {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write('$error\n$stackTrace');
        await request.response.close();
      }
    });
  });

  tearDown(() async {
    await subscription.cancel();
    await server.close(force: true);
  });

  group('ApiClient', () {
    test('GET 携带查询与 Token 头并解密统一响应', () async {
      late HttpRequest captured;
      handler = (request) async {
        captured = request;
        await _replyData(request, {'id': 42, 'name': 'ok'});
      };

      final body = await ApiClient(host: () => baseUrl).getAlbum(42);
      expect(jsonDecode(body), {'id': 42, 'name': 'ok'});
      expect(captured.method, 'GET');
      expect(captured.uri.path, Endpoints.album);
      expect(captured.uri.queryParameters['id'], '42');
      expect(captured.headers.value('Tokenparam'), endsWith(',$kAppVersion'));
      expect(captured.headers.value('Token'), hasLength(32));
      expect(captured.headers.value(HttpHeaders.userAgentHeader), kUserAgent);
    });

    test('POST 使用 multipart form 发送登录字段', () async {
      late String requestBody;
      handler = (request) async {
        requestBody = await utf8.decoder.bind(request).join();
        await _replyData(request, {'uid': 1});
      };

      await ApiClient(host: () => baseUrl).login('alice', 'secret');
      expect(requestBody, contains('name="username"'));
      expect(requestBody, contains('alice'));
      expect(requestBody, contains('name="password"'));
      expect(requestBody, contains('secret'));
    });

    test('同机 5xx 最多重试三次并返回最后成功结果', () async {
      var attempts = 0;
      handler = (request) async {
        attempts++;
        if (attempts < 3) {
          await _replyError(request, 503, 'busy');
        } else {
          await _replyData(request, {'ok': true});
        }
      };

      final body = await ApiClient(host: () => baseUrl).getAlbum(1);
      expect(jsonDecode(body), {'ok': true});
      expect(attempts, 3);
    });

    test('HTTP 400 不重试并保留服务端错误信息', () async {
      var attempts = 0;
      handler = (request) async {
        attempts++;
        await _replyError(request, 400, 'bad request');
      };

      await expectLater(
        ApiClient(host: () => baseUrl).getAlbum(1),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'statusCode', 400)
              .having((error) => error.message, 'message', contains('bad request')),
        ),
      );
      expect(attempts, 1);
    });

    test('业务错误码保留 apiCode', () async {
      handler = (request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'code': 403, 'errorMsg': '登录失效'}));
        await request.response.close();
      };

      await expectLater(
        ApiClient(host: () => baseUrl).getAlbum(1),
        throwsA(
          isA<ApiException>().having((error) => error.apiCode, 'apiCode', 403),
        ),
      );
    });

    test('空主机、非法 JSON 与缺失 data 分别给出明确异常', () async {
      await expectLater(
        ApiClient(host: () => null).getAlbum(1),
        throwsA(isA<ApiException>().having((error) => error.message, 'message', '没有可用 API 域名')),
      );

      handler = (request) async {
        request.response.write('not-json');
        await request.response.close();
      };
      await expectLater(
        ApiClient(host: () => baseUrl).getAlbum(1),
        throwsA(isA<ApiException>().having((error) => error.message, 'message', '响应不是有效的 JSON')),
      );

      handler = (request) async {
        request.response.write(jsonEncode({'code': 200, 'data': null}));
        await request.response.close();
      };
      await expectLater(
        ApiClient(host: () => baseUrl).getAlbum(1),
        throwsA(isA<ApiException>().having((error) => error.message, 'message', '接口返回数据为空')),
      );
    });
  });

  group('ApiRepository', () {
    test('专辑章节按 sort 排序、空名称兜底，空列表构造单章', () async {
      handler = (request) async {
        final id = int.parse(request.uri.queryParameters['id']!);
        if (id == 42) {
          await _replyData(
            request,
            _albumPayload(
              series: [
                {'id': 2, 'name': '', 'sort': '2'},
                {'id': 1, 'name': '第一话', 'sort': '1'},
              ],
            ),
          );
        } else {
          await _replyData(request, _albumPayload(id: id));
        }
      };
      final repository = ApiRepository(() => baseUrl);

      final detail = await repository.getAlbum(42);
      expect(detail.series.map((item) => item.id), [1, 2]);
      expect(detail.series.last.name, '第2话');
      final single = await repository.getAlbum(99);
      expect(single.series.single.id, 99);
      expect(single.series.single.name, '第1话');
    });

    test('禁漫号搜索会继续拉取专辑并组装单条结果', () async {
      final paths = <String>[];
      handler = (request) async {
        paths.add(request.uri.path);
        if (request.uri.path == Endpoints.search) {
          await _replyData(request, {
            'search_query': '42',
            'total': 1,
            'content': const [],
            'redirect_aid': 42,
          });
        } else {
          await _replyData(request, _albumPayload());
        }
      };

      final result = await ApiRepository(() => baseUrl).search('42', 1, SearchSort.latest);
      expect(paths, [Endpoints.search, Endpoints.album]);
      expect(result.redirectAid, 42);
      expect(result.content.single.id, 42);
      expect(result.content.single.author, '作者甲 作者乙');
    });

    test('scramble HTML 正常解析，格式异常回退默认值', () async {
      var valid = true;
      handler = (request) async {
        request.response.write(
          valid ? '<script>var scramble_id = 123456;</script>' : '<html>none</html>',
        );
        await request.response.close();
      };
      final repository = ApiRepository(() => baseUrl);
      expect(await repository.getScrambleId(42), 123456);
      valid = false;
      expect(await repository.getScrambleId(42), kAppScrambleId);
    });

    test('分类名称按接口约定转换为繁体参数', () async {
      late String category;
      handler = (request) async {
        category = request.uri.queryParameters['c']!;
        await _replyData(request, {'search_query': category, 'total': 0, 'content': const []});
      };
      await ApiRepository(() => baseUrl).getCategoriesFilter('禁漫汉化组', 1, CategorySort.latest);
      expect(category, '禁漫漢化組');
    });
  });
}
