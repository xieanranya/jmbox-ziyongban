/// 每日签到模型。
library;

import '../../core/utils/json_utils.dart';

class DailyRecord {
  const DailyRecord({required this.date, required this.signed, required this.bonus});

  factory DailyRecord.fromJson(Map<String, dynamic> json) => DailyRecord(
    date: json['date'] as String? ?? '',
    signed: json['signed'] as bool?,
    bonus: json['bonus'] as bool? ?? false,
  );

  /// 当月第几天，形如 "01"。
  final String date;

  /// 当日是否已签到；未来日期为 null。
  final bool? signed;

  final bool bonus;
}

class DailyInfo {
  const DailyInfo({
    required this.dailyId,
    required this.threeDaysCoin,
    required this.threeDaysExp,
    required this.sevenDaysCoin,
    required this.sevenDaysExp,
    required this.eventName,
    required this.currentProgress,
    required this.record,
  });

  factory DailyInfo.fromJson(Map<String, dynamic> json) => DailyInfo(
    dailyId: toInt(json['daily_id']),
    threeDaysCoin: json['three_days_coin'] as String? ?? '',
    threeDaysExp: json['three_days_exp'] as String? ?? '',
    sevenDaysCoin: json['seven_days_coin'] as String? ?? '',
    sevenDaysExp: json['seven_days_exp'] as String? ?? '',
    eventName: json['event_name'] as String? ?? '',
    currentProgress: json['currentProgress'] as String? ?? '',
    record: _parseRecord(json['record']),
  );

  /// 解析按周分组的签到记录（嵌套列表：周 → 日记录），缺失或结构不符回退空列表。
  static List<List<DailyRecord>> _parseRecord(Object? value) {
    if (value is! List) return const [];
    return [
      for (final week in value)
        if (week is List)
          [
            for (final item in week)
              if (item is Map) DailyRecord.fromJson(Map<String, dynamic>.from(item)),
          ]
        else
          const <DailyRecord>[],
    ];
  }

  /// 本次签到所需的 daily_id（传给 checkDaily）。
  final int dailyId;
  final String threeDaysCoin;
  final String threeDaysExp;
  final String sevenDaysCoin;
  final String sevenDaysExp;
  final String eventName;
  final String currentProgress;

  /// 签到记录，按周分组。
  final List<List<DailyRecord>> record;
}

class DailyChk {
  const DailyChk({required this.msg});

  factory DailyChk.fromJson(Map<String, dynamic> json) =>
      DailyChk(msg: json['msg'] as String? ?? '');

  final String msg;
}
