/// 应用配置模型（config.json）。
library;

import '../../core/constants/enhance.dart';
import '../../core/constants/theme.dart';

class AppConfig {
  const AppConfig({
    this.username = '',
    this.password = '',
    this.apiHost = '',
    this.imageAuto = true,
    this.imageHost = '',
    this.autoCheckin = false,
    this.themeSetting = ThemeSetting.system,
    this.enhanceLevel = EnhanceLevel.off,
    this.proxyEnabled = false,
    this.proxyHost = '127.0.0.1',
    this.proxyPort = 7890,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) => AppConfig(
    username: json['username'] as String? ?? '',
    password: json['password'] as String? ?? '',
    apiHost: json['api_host'] as String? ?? '',
    imageAuto: json['image_auto'] as bool? ?? true,
    imageHost: json['image_host'] as String? ?? '',
    autoCheckin: json['auto_checkin'] as bool? ?? false,
    themeSetting: ThemeSetting.values.firstWhere(
      (e) => e.value == json['theme_setting'],
      orElse: () => ThemeSetting.system,
    ),
    enhanceLevel: EnhanceLevel.fromValue(json['enhance_level'] as String?),
    proxyEnabled: json['proxy_enabled'] as bool? ?? false,
    proxyHost: json['proxy_host'] as String? ?? '127.0.0.1',
    proxyPort: json['proxy_port'] as int? ?? 7890,
  );

  final String username;
  final String password;

  /// API 固定域名；空或不在当前域名列表内时回退到列表第一台。
  final String apiHost;

  final bool imageAuto;

  /// 图片手动固定域名，空串表示自动选路。
  final String imageHost;

  /// 登录成功后自动执行每日签到。
  final bool autoCheckin;

  final ThemeSetting themeSetting;

  /// 画质增强（超级分辨率）档位。
  final EnhanceLevel enhanceLevel;

  /// 是否启用 HTTP 代理（API 与图片请求都走）。
  final bool proxyEnabled;

  /// 代理主机。
  final String proxyHost;

  /// 代理端口。
  final int proxyPort;

  /// 展示用代理地址。
  String get proxyDisplay => '${proxyHost.trim()}:$proxyPort';

  Map<String, dynamic> toJson() => {
    'username': username,
    'password': password,
    'api_host': apiHost,
    'image_auto': imageAuto,
    'image_host': imageHost,
    'auto_checkin': autoCheckin,
    'theme_setting': themeSetting.value,
    'enhance_level': enhanceLevel.value,
    'proxy_enabled': proxyEnabled,
    'proxy_host': proxyHost,
    'proxy_port': proxyPort,
  };

  AppConfig copyWith({
    String? username,
    String? password,
    String? apiHost,
    bool? imageAuto,
    String? imageHost,
    bool? autoCheckin,
    ThemeSetting? themeSetting,
    EnhanceLevel? enhanceLevel,
    bool? proxyEnabled,
    String? proxyHost,
    int? proxyPort,
  }) => AppConfig(
    username: username ?? this.username,
    password: password ?? this.password,
    apiHost: apiHost ?? this.apiHost,
    imageAuto: imageAuto ?? this.imageAuto,
    imageHost: imageHost ?? this.imageHost,
    autoCheckin: autoCheckin ?? this.autoCheckin,
    themeSetting: themeSetting ?? this.themeSetting,
    enhanceLevel: enhanceLevel ?? this.enhanceLevel,
    proxyEnabled: proxyEnabled ?? this.proxyEnabled,
    proxyHost: proxyHost ?? this.proxyHost,
    proxyPort: proxyPort ?? this.proxyPort,
  );
}
