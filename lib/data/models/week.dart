/// 每周必看模型。
library;

import '../../core/utils/json_utils.dart';

/// 时间段分类（一期）。
class WeekCategory {
  const WeekCategory({required this.id, required this.title, required this.time});

  factory WeekCategory.fromJson(Map<String, dynamic> json) => WeekCategory(
    id: toInt(json['id']),
    title: json['title'] as String? ?? '',
    time: json['time'] as String? ?? '',
  );

  final int id;
  final String title;
  final String time;

  @override
  bool operator ==(Object other) =>
      other is WeekCategory && other.id == id && other.title == title && other.time == time;

  @override
  int get hashCode => Object.hash(id, title, time);
}

/// 类型（hanman/another/manga）。
class WeekType {
  const WeekType({required this.id, required this.title});

  factory WeekType.fromJson(Map<String, dynamic> json) =>
      WeekType(id: json['id'] as String? ?? '', title: json['title'] as String? ?? '');

  final String id;
  final String title;
}

class WeekInfo {
  const WeekInfo({required this.categories, required this.weekTypes});

  factory WeekInfo.fromJson(Map<String, dynamic> json) => WeekInfo(
    categories: toList(json['categories'], WeekCategory.fromJson),
    weekTypes: toList(json['type'], WeekType.fromJson),
  );

  final List<WeekCategory> categories;
  final List<WeekType> weekTypes;
}
