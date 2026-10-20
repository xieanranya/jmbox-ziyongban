/// 签到模块 Provider：签到信息（按用户懒加载）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/daily.dart';
import '../../../data/providers.dart';

final dailyProvider = FutureProvider.autoDispose.family<DailyInfo, String>(
  (ref, userId) => ref.read(apiRepositoryProvider).getDaily(userId),
);
