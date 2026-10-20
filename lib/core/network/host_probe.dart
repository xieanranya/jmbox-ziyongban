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
import 'proxy_config.dart';

/// 单台主机探活：[timeout] 内拿到任意 HTTP 响应即存活。
/// [proxy] 非空且启用时经代理探测（验证代理链路是否可用）。
Future<bool> probeHost(
  String host, {
  Duration timeout = const Duration(seconds: 4),
  ProxyConfig? proxy,
}) async {
  final dio = _buildProbeDio(timeout, proxy);
  try {
    await dio.get<void>('$host/');
    return true;
  } on DioException catch (e) {
    return e.response != null;
  } catch (_) {
    return false;
  } finally {
    dio.close(force: true);
  }
}

/// 单台主机计时探活（网络诊断用）：返回 (是否可达, 耗时毫秒)。
Future<(bool, int)> probeHostDetailed(
  String host, {
  Duration timeout = const Duration(seconds: 4),
  ProxyConfig? proxy,
}) async {
  final dio = _buildProbeDio(timeout, proxy);
  final sw = Stopwatch()..start();
  try {
    await dio.get<void>('$host/');
    return (true, sw.elapsedMilliseconds);
  } on DioException catch (e) {
    return (e.response != null, sw.elapsedMilliseconds);
  } catch (_) {
    return (false, sw.elapsedMilliseconds);
  } finally {
    sw.stop();
    dio.close(force: true);
  }
}

/// 并发探测全部候选主机，返回存活主机列表（添加顺序 ≈ 响应速度顺序）。
Future<List<String>> probeAliveHosts(
  Iterable<String> hosts, {
  Duration timeout = const Duration(seconds: 4),
  ProxyConfig? proxy,
}) async {
  final alive = <String>[];
  await Future.wait([
    for (final host in hosts)
      probeHost(host, timeout: timeout, proxy: proxy).then((ok) {
        if (ok) alive.add(host);
      }),
  ]);
  return alive;
}

/// 探活专用 Dio：任意状态码都不算错（能收到 HTTP 响应即链路可达）。
Dio _buildProbeDio(Duration timeout, ProxyConfig? proxy) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: timeout,
      receiveTimeout: timeout,
      sendTimeout: timeout,
      headers: {'User-Agent': kUserAgent},
      validateStatus: (_) => true,
    ),
  );
  configureDioProxy(dio, proxy);
  return dio;
}
