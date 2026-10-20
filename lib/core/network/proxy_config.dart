/// HTTP 代理配置（直连兜底方案）。
///
/// 背景：API/图片域名均为 CDN 域名、按「国内直连」设计（启动探活 + 多线路切换），
/// 多数网络环境下不需要代理；个别网络（DNS 污染 / 运营商拦截 / 海外网络）
/// 直连全部失败时，可经本配置走 HTTP 代理。
///
/// 注意：dart:io 的 `HttpClient.findProxy` 只支持 `DIRECT` 与 `PROXY host:port`
/// （HTTP CONNECT），不支持 SOCKS——Clash/v2ray 等客户端的「混合端口」即 HTTP 代理。
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

class ProxyConfig {
  const ProxyConfig({this.enabled = false, this.host = '127.0.0.1', this.port = 7890});

  /// 直连（不经过任何代理）。
  const ProxyConfig.disabled() : enabled = false, host = '127.0.0.1', port = 7890;

  /// 是否启用代理。
  final bool enabled;

  /// 代理主机（手机模拟器/本机一般为 127.0.0.1）。
  final String host;

  /// 代理端口。
  final int port;

  /// [HttpClient.findProxy] 返回值；null 表示直连。
  ///
  /// 主机为空或端口非法时视为未启用，避免把请求送进黑洞。
  String? get findProxyValue {
    if (!valid) return null;
    return 'PROXY ${host.trim()}:$port';
  }

  /// 配置是否可用（启用且主机端口合法）。
  bool get valid => enabled && host.trim().isNotEmpty && port > 0 && port <= 65535;

  /// 展示用地址，如 `127.0.0.1:7890`。
  String get display => '${host.trim()}:$port';

  ProxyConfig copyWith({bool? enabled, String? host, int? port}) {
    return ProxyConfig(
      enabled: enabled ?? this.enabled,
      host: host ?? this.host,
      port: port ?? this.port,
    );
  }
}

/// 常用代理预设（本地代理客户端混合端口）。
abstract final class ProxyPresets {
  static const clash = ('127.0.0.1', 7890, 'Clash 默认混合端口');
  static const clashVerge = ('127.0.0.1', 10809, 'Clash Verge 默认');
  static const v2rayN = ('127.0.0.1', 1080, 'v2rayN 默认');
  static const generic = ('127.0.0.1', 8080, '通用 HTTP 代理');
}

/// 给 [dio] 装上代理适配器：每次请求都会新建/复用 [HttpClient]，
/// [ProxyConfig.findProxyValue] 为 null 时显式 DIRECT（忽略环境变量代理，行为可预期）。
void configureDioProxy(Dio dio, ProxyConfig? proxy) {
  final value = proxy?.findProxyValue;
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient();
      client.findProxy = value == null ? (uri) => 'DIRECT' : (uri) => value;
      return client;
    },
  );
}
