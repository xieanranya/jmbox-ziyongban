/// 每周必看模型：期数列表（categories）+ 三个板块（type：日漫/其他/韩漫）。
library;

import '../../core/utils/json_utils.dart';
import 'album.dart';

/// 每周必看信息：期数清单 + 板块清单。
class WeekInfo {
  const WeekInfo({required this.categories, required this.type});

  factory WeekInfo.fromJson(Map<String, dynamic> json) => WeekInfo(
    categories: toList(json['categories'], WeekIssue.fromJson),
    type: toList(json['type'], WeekType.fromJson),
  );

  /// 期数列表（新→旧），如 2026第261期10.16 - 10.09。
  final List<WeekIssue> categories;

  /// 板块列表：日漫 / 其他 / 韩漫。
  final List<WeekType> type;

  /// 按展示顺序排好的板块（参考图顺序：日漫 → 其他 → 韩漫）。
  List<WeekType> get orderedType {
    const order = {'manga': 0, 'another': 1, 'hanman': 2};
    final list = type.toList()
      ..sort((a, b) => (order[a.id] ?? 99).compareTo(order[b.id] ?? 99));
    return list;
  }
}

/// 一期（如 2026第261期10.16 - 10.09）。
class WeekIssue {
  const WeekIssue({required this.id, required this.time});

  factory WeekIssue.fromJson(Map<String, dynamic> json) => WeekIssue(
    id: json['id'] as String? ?? '',
    time: json['time'] as String? ?? '',
  );

  /// 期号 id（week/filter 的 id 入参）。
  final String id;

  /// 展示文案：2026第261期10.16 - 10.09。
  final String time;
}

/// 一个板块（日漫 / 其他 / 韩漫）。
class WeekType {
  const WeekType({required this.id, required this.title});

  factory WeekType.fromJson(Map<String, dynamic> json) => WeekType(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
  );

  /// 板块 id（week/filter 的 type 入参）：manga / another / hanman。
  final String id;

  /// 板块名：日漫 / 其他 / 韩漫。
  final String title;
}

/// 某一期某一板块的内容（整期一次返回，无分页）。
class WeekList {
  const WeekList({required this.total, required this.list});

  factory WeekList.fromJson(Map<String, dynamic> json) => WeekList(
    total: toInt(json['total']),
    list: toList(json['list'], AlbumBrief.fromJson),
  );

  final int total;
  final List<AlbumBrief> list;
}
