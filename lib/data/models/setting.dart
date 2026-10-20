/// 应用设置模型。
library;

import '../../core/utils/json_utils.dart';

/// 应用设置（/setting 接口）。
class AppSetting {
  const AppSetting({this.apiVersion, this.imageHost, this.shunts = const []});

  factory AppSetting.fromJson(Map<String, dynamic> json) => AppSetting(
    apiVersion: json['jm3_version'] as String? ?? json['version'] as String?,
    imageHost: json['img_host'] as String? ?? json['imgHost'] as String?,
    shunts: toList(json['app_shunts'], ApiShunt.fromJson),
  );

  final String? apiVersion;

  /// 服务端推荐的图片主机。
  final String? imageHost;

  final List<ApiShunt> shunts;

  @override
  String toString() =>
      'AppSetting(apiVersion: $apiVersion, imageHost: $imageHost, '
      'shunts: $shunts)';
}

class ApiShunt {
  const ApiShunt({required this.id, required this.name});

  factory ApiShunt.fromJson(Map<String, dynamic> json) => ApiShunt(
    // 服务端字段为 key（数字），兼容 id/value
    id: json['key']?.toString() ?? json['id'] as String? ?? json['value'] as String? ?? '',
    name: json['title'] as String? ?? json['name'] as String? ?? '',
  );

  final String id;
  final String name;

  @override
  String toString() => 'ApiShunt(id: $id, name: $name)';
}
