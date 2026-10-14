import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jmbox/core/constants/app_constants.dart';
import 'package:jmbox/core/network/exception.dart';
import 'package:jmbox/core/utils/format.dart';
import 'package:jmbox/core/utils/host.dart';
import 'package:jmbox/core/utils/jm_crypto.dart';
import 'package:jmbox/core/utils/json_utils.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/ecb.dart';
import 'package:pointycastle/padded_block_cipher/padded_block_cipher_impl.dart';
import 'package:pointycastle/paddings/pkcs7.dart';

String _encrypt(String keyHex, String plainText) {
  final cipher = PaddedBlockCipherImpl(PKCS7Padding(), ECBBlockCipher(AESEngine()))
    ..init(
      true,
      PaddedBlockCipherParameters<KeyParameter, Null>(
        KeyParameter(Uint8List.fromList(utf8.encode(keyHex))),
        null,
      ),
    );
  return base64Encode(cipher.process(Uint8List.fromList(utf8.encode(plainText))));
}

void main() {
  group('展示格式', () {
    test('字节单位在边界处正确换算', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(1023), '1023 B');
      expect(formatBytes(1024), '1.0 KB');
      expect(formatBytes(1024 * 1024), '1.0 MB');
      expect(formatBytes(1024 * 1024 * 1024), '1.00 GB');
    });

    test('计数达到一万后压缩并移除无意义小数', () {
      expect(compactCount(9999), '9999');
      expect(compactCount(10000), '1万');
      expect(compactCount(12500), '1.3万');
    });

    test('时间戳按本地日期格式化，普通文本原样返回', () {
      final seconds = DateTime(2024, 2, 3, 12).millisecondsSinceEpoch ~/ 1000;
      expect(formatDate('$seconds'), '2024-02-03');
      expect(formatDate('刚刚'), '刚刚');
    });
  });

  group('主机规范化', () {
    test('补协议并移除路径、查询和末尾斜杠', () {
      expect(normalizedBaseUrlOrNull(' example.com/a?x=1 '), 'https://example.com');
      expect(normalizedBaseUrlOrNull('http://api.example.com/'), 'http://api.example.com');
    });

    test('空值、缺少主机和非法主机字符返回 null', () {
      expect(normalizedBaseUrlOrNull(''), isNull);
      expect(normalizedBaseUrlOrNull('https:///path'), isNull);
      expect(normalizedBaseUrlOrNull('https://exa_mple.com'), isNull);
    });

    test('剥离 http/https 协议并先清理空白', () {
      expect(stripScheme(' https://example.com '), 'example.com');
      expect(stripScheme('http://example.com'), 'example.com');
      expect(stripScheme('example.com'), 'example.com');
    });
  });

  group('JSON 兼容解析', () {
    test('Map 与 List 异步解析入口返回正确结构', () async {
      expect(await parseJsonMap(Future.value('{"id":1}')), {'id': 1});
      expect(await parseJsonList(Future.value('[1,"2"]')), [1, '2']);
    });

    test('整数兼容 int、double、字符串和非法值', () {
      expect(toInt(7), 7);
      expect(toInt(7.9), 7);
      expect(toInt('8'), 8);
      expect(toInt('bad'), 0);
      expect(toInt(null), 0);
    });

    test('列表解析过滤类型不符的成员', () {
      expect(toStringList(['a', 1, 'b']), ['a', 'b']);
      expect(toStringList('a'), isEmpty);
      final ids = toList([
        {'id': '2'},
        'bad',
      ], (json) => toInt(json['id']));
      expect(ids, [2]);
    });
  });

  group('JM 加密规则', () {
    test('Tokenparam 与 Token 可重复计算且区分 scramble 密钥', () {
      const time = 1700000000;
      expect(buildTokenparam(time), '$time,$kAppVersion');
      expect(buildToken(time, false), md5.convert(utf8.encode('$time$kAppTokenSecret')).toString());
      expect(buildToken(time, true), isNot(buildToken(time, false)));
    });

    test('AES-256-ECB 解密已知明文', () {
      const time = 1700000000;
      final key = md5.convert(utf8.encode('$time$kAppDataSecret')).toString();
      final encrypted = _encrypt(key, '{"ok":true,"text":"测试"}');
      expect(decryptJmData(time, encrypted), '{"ok":true,"text":"测试"}');
    });

    test('图片分块数覆盖未打乱、固定 10 块与哈希分支', () {
      expect(calculateBlockNum(100, 99, '00001.webp'), 0);
      expect(calculateBlockNum(0, 200000, '00001.webp'), 10);
      expect(calculateBlockNum(0, 300000, '00001.webp'), inInclusiveRange(2, 20));
      expect(calculateBlockNum(0, 500000, '00001'), calculateBlockNum(0, 500000, '00001.webp'));
    });
  });

  group('ApiException', () {
    test('只对同机可恢复故障重试', () {
      expect(const ApiException('network', isNetworkError: true).retryableOnSameHost, isTrue);
      expect(const ApiException('timeout', statusCode: 408).retryableOnSameHost, isTrue);
      expect(const ApiException('busy', statusCode: 429).retryableOnSameHost, isTrue);
      expect(const ApiException('server', statusCode: 503).retryableOnSameHost, isTrue);
      expect(const ApiException('forbidden', statusCode: 403).retryableOnSameHost, isFalse);
      expect(const ApiException('business', apiCode: 500).retryableOnSameHost, isFalse);
    });

    test('toString 携带消息', () {
      expect(
        const ApiException('boom').toString(),
        'ApiException: boom (statusCode: null, apiCode: null, isNetworkError: false)',
      );
    });
  });
}
