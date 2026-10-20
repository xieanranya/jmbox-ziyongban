/// JSON 解析工具：兼容 JM 接口的字段漂移（数字/字符串）与缺失。
library;

import 'dart:convert';

/// 解析接口响应为 Map（统一入口）。
Future<Map<String, dynamic>> parseJsonMap(Future<String> future) async =>
    jsonDecode(await future) as Map<String, dynamic>;

/// 解析接口响应为 List（统一入口）。
Future<List<dynamic>> parseJsonList(Future<String> future) async =>
    jsonDecode(await future) as List;

/// 兼容数字/字符串的整数解析，无法解析回退 0。
int toInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

/// 解析字符串列表，缺失或非列表回退空列表。
List<String> toStringList(Object? value) {
  if (value is! List) return const [];
  return value.whereType<String>().toList();
}

/// 解析对象列表，逐项用 [fromJson] 转换，缺失或非列表回退空列表。
List<T> toList<T>(Object? value, T Function(Map<String, dynamic>) fromJson) {
  if (value is! List) return const [];
  return value.whereType<Map>().map((e) => fromJson(Map<String, dynamic>.from(e))).toList();
}
