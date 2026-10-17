/// 主机探活：短超时并发探测候选域名，用于启动/刷新时把会话冻结在实测可用的主机上。
///
/// 背景：API/图片主机运行期冻结（会话按域名签发，换机必 401），域名服务器拉取
/// 失败或首选线路抖动时会冻结在坏机器上，表现为整个会话全挂（用户以为必须开代理）。
/// 探活判活标准：拿到任意 HTTP 响应（含 403/404）即视为网络层可达——API 域名根
/// 路径可能 403、图片域名根路径可能 404，都代表 TLS/HTTP 链路正常，业务请求由
/// 各自客户端带上正确头后完成。
library;

import 'package:dio/dio.dart';

import '../constants/app_constants.dart';

/// 单台主机探活：[timeout] 内拿到任意 HTTP 响应即存活。
Future<bool> probeHost(String host, {Duration timeout = const Duration(seconds: 4)}) async {
  final dio = Dio(
    BaseOptions(
      connectTimeout: timeout,
      receiveTimeout: timeout,
      sendTimeout: timeout,
      headers: {'User-Agent': kUserAgent},
      // 任意状态码都不算错：能收到 HTTP 响应就说明网络层可达
      validateStatus: (_) => true,
    ),
  );
  try {
    await dio.get<void>('$host/');
    return true;
  } on DioException catch (e) {
    return e.response != null;
  } catch (_) {
    return false;
  } finally {
    dio.close();
  }
}

/// 并发探测全部候选主机，返回存活主机列表（添加顺序 ≈ 响应速度顺序）。
Future<List<String>> probeAliveHosts(
  Iterable<String> hosts, {
  Duration timeout = const Duration(seconds: 4),
}) async {
  final alive = <String>[];
  await Future.wait([
    for (final host in hosts)
      probeHost(host, timeout: timeout).then((ok) {
        if (ok) alive.add(host);
      }),
  ]);
  return alive;
}
