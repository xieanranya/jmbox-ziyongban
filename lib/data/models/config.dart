/// 应用配置模型（config.json）。
library;

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

  Map<String, dynamic> toJson() => {
    'username': username,
    'password': password,
    'api_host': apiHost,
    'image_auto': imageAuto,
    'image_host': imageHost,
    'auto_checkin': autoCheckin,
    'theme_setting': themeSetting.value,
  };

  AppConfig copyWith({
    String? username,
    String? password,
    String? apiHost,
    bool? imageAuto,
    String? imageHost,
    bool? autoCheckin,
    ThemeSetting? themeSetting,
  }) => AppConfig(
    username: username ?? this.username,
    password: password ?? this.password,
    apiHost: apiHost ?? this.apiHost,
    imageAuto: imageAuto ?? this.imageAuto,
    imageHost: imageHost ?? this.imageHost,
    autoCheckin: autoCheckin ?? this.autoCheckin,
    themeSetting: themeSetting ?? this.themeSetting,
  );
}
