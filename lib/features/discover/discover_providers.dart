/// 发现页数据流。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/category.dart';
import '../../data/models/week.dart';
import '../../data/providers.dart';

/// 分类信息（一级分类 + blocks 标签云）。
final categoriesProvider = FutureProvider.autoDispose<CategoryInfo>((ref) {
  return ref.watch(apiRepositoryProvider).getCategories();
});

/// 每周必看信息（期数列表，供「每周必看」入口构造筛选源）。
final weekInfoProvider = FutureProvider.autoDispose<WeekInfo>((ref) {
  return ref.watch(apiRepositoryProvider).getWeekInfo();
});
