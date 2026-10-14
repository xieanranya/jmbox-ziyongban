/// JM 加密工具：Token 计算、AES-256-ECB 解密、图片分块数计算。
///
/// 域名/主机相关工具见同目录 host.dart。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/ecb.dart';
import 'package:pointycastle/padded_block_cipher/padded_block_cipher_impl.dart';
import 'package:pointycastle/paddings/pkcs7.dart';

import '../constants/app_constants.dart';

// ---- Token 计算 ----

/// 当前 Unix 时间戳（秒）。
int nowSeconds() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

/// 生成 Tokenparam 头：`{time},{appVersion}`。
String buildTokenparam(int time) => '$time,$kAppVersion';

/// 生成 Token 头：`md5(time + secret)`。
/// [isScramble] 为 true 时使用 scramble 专用密钥。
String buildToken(int time, bool isScramble) {
  final secret = isScramble ? kAppTokenSecret2 : kAppTokenSecret;
  return md5.convert(utf8.encode('$time$secret')).toString();
}

// ---- AES 解密 ----

/// 解密 JM API 响应数据：Base64 → AES-256-ECB(PKCS7) → UTF-8。
/// 密钥 = `md5(time + kAppDataSecret)` 的 ASCII 字节（32 字节）。
String decryptJmData(int time, String data) {
  final keyHex = md5.convert(utf8.encode('$time$kAppDataSecret')).toString();
  return decryptJmDataWithKey(keyHex, data);
}

/// 用指定 hex 密钥解密（密钥为 32 字节 hex 字符串的 ASCII 字节）。
String decryptJmDataWithKey(String keyHex, String data) {
  final key = Uint8List.fromList(utf8.encode(keyHex));
  final cipherText = base64.decode(data);
  final plain = _aes256EcbDecrypt(key, cipherText);
  return utf8.decode(plain);
}

/// AES-256-ECB 解密（PKCS7 自动去填充）。
Uint8List _aes256EcbDecrypt(Uint8List key, Uint8List cipherText) {
  final cipher = PaddedBlockCipherImpl(PKCS7Padding(), ECBBlockCipher(AESEngine()))
    ..init(false, PaddedBlockCipherParameters<KeyParameter, Null>(KeyParameter(key), null));
  return cipher.process(cipherText);
}

// ---- 图片分块还原 ----

/// 计算章节图片的分块数：未打乱返回 0，打乱返回 2~18 的偶数。[filename] 扩展名
/// 不参与计算。规则移植自 JM 客户端社区实现，详见函数体内注释。
int calculateBlockNum(int scrambleId, int id, String filename) {
  // 去掉扩展名：参与 md5 的只有纯图片名
  final dotIndex = filename.lastIndexOf('.');
  final name = dotIndex > 0 ? filename.substring(0, dotIndex) : filename;

  if (id < scrambleId) return 0; // 未打乱
  if (id < 268850) return 10;
  // 以 md5("$id$name") 尾字符 ASCII 对 x（按序号分段取 10 或 8）取模
  final x = id < 421926 ? 10 : 8;
  final s = md5.convert(utf8.encode('$id$name')).toString();
  final last = s.codeUnitAt(s.length - 1);
  return (last % x) * 2 + 2;
}
