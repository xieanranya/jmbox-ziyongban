library;

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../constants/app_constants.dart';
import 'exception.dart';
import '../utils/jm_crypto.dart';

/// API 域名获取器：多服务器并发竞速，返回最新 API 域名列表。
///
/// 域名服务器是静态文件托管，无需 Cookie/Token 认证，使用裸 dio。
class ApiDomainFetcher {
  ApiDomainFetcher({this._serverUrls = kDomainServerUrls})
    : _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          headers: {'User-Agent': kUserAgent},
        ),
      );

  final List<String> _serverUrls;
  final Dio _dio;

  /// 获取最新 API 域名列表（多服务器并发竞速，首个成功即返回）。
  Future<List<String>> fetch() async {
    if (_serverUrls.isEmpty) {
      throw const ApiException('未配置域名服务器');
    }
    final hosts = await Stream.fromFutures(_serverUrls.map(_tryFetch))
        .firstWhere((hosts) => hosts != null, orElse: () => null);
    if (hosts == null) {
      throw const ApiException('全部域名服务器刷新失败');
    }
    return hosts;
  }

  /// 单台服务器拉取，失败返回 null（不抛出）。
  Future<List<String>?> _tryFetch(String url) async {
    try {
      return await _fetch(url);
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> _fetch(String url) async {
    final response = await _dio.get<String>(
      url,
      options: Options(responseType: ResponseType.plain),
    );
    final clean = _trimLeadingNonAscii(response.data ?? '');
    if (clean.isEmpty) {
      throw const ApiException('域名服务器响应为空');
    }
    final keyHex = md5.convert(utf8.encode(kDomainServerSecret)).toString();
    final json = decryptJmDataWithKey(keyHex, clean);
    final root = jsonDecode(json) as Map<String, dynamic>;
    final server = root['Server'];
    final hosts = <String>[];
    if (server is List) {
      for (final item in server) {
        if (item is String && item.trim().isNotEmpty) {
          hosts.add(item.trim());
        }
      }
    }
    if (hosts.isEmpty) {
      throw const ApiException('域名服务器未返回可用 API 域名');
    }
    return hosts;
  }

  /// 去掉前导非 ASCII 字符（如 BOM）。
  String _trimLeadingNonAscii(String text) {
    var index = 0;
    while (index < text.length && text.codeUnitAt(index) > 127) {
      index++;
    }
    return text.substring(index).trim();
  }
}
