/// 每周必看数据流。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/week.dart';
import '../../data/providers.dart';

/// 期数 + 板块信息（期数列表 + 日漫/其他/韩漫）。
final weekInfoProvider = FutureProvider.autoDispose<WeekInfo>((ref) {
  return ref.watch(apiRepositoryProvider).getWeekInfo();
});

/// 内容查询参数：期号 id + 板块 type。
class WeekQuery {
  const WeekQuery(this.id, this.type);

  final String id;
  final String type;

  @override
  bool operator ==(Object other) =>
      other is WeekQuery && other.id == id && other.type == type;

  @override
  int get hashCode => Object.hash(id, type);
}

/// 某一期某一板块的内容（整期一次返回，无分页）。
final weekContentProvider =
    FutureProvider.autoDispose.family<WeekList, WeekQuery>((ref, q) {
  return ref.watch(apiRepositoryProvider).getWeekFilter(q.id, q.type);
});
