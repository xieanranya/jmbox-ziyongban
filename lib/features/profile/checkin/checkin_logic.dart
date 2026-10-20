/// 每日签到页纯逻辑（移植自 komikku，无 UI 依赖）。
library;

import '../../../data/models/daily.dart';

/// 日历单元格；[day] 为 null 表示空白占位。
class CalendarCell {
  const CalendarCell(this.day, {this.signed = false, this.bonus = false, this.today = false});

  final int? day;
  final bool signed;
  final bool bonus;
  final bool today;
}

/// 记录日期 → 当月第几天（取最后一段）。
int? _recordDay(String date) => int.tryParse(date.trim().split('-').last);

/// 记录按「当月第几天」索引（同一天多条取最后一条）。
Map<int, DailyRecord> recordsOf(DailyInfo info) => {
  for (final week in info.record)
    for (final r in week) ?_recordDay(r.date): r,
};

/// 当月日历格子：周一开头，前导补空，尾部补齐到 42 格。
List<CalendarCell> monthCells(DateTime now, Map<int, DailyRecord> records) {
  final leading = DateTime(now.year, now.month, 1).weekday - DateTime.monday;
  final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
  final cells = <CalendarCell>[
    for (var i = 0; i < leading; i++) const CalendarCell(null),
    for (var day = 1; day <= daysInMonth; day++)
      CalendarCell(
        day,
        signed: records[day]?.signed == true,
        bonus: records[day]?.bonus == true,
        today: day == now.day,
      ),
  ];
  while (cells.length % 7 != 0 || cells.length < 42) {
    cells.add(const CalendarCell(null));
  }
  return cells;
}

/// 今日是否已签。
bool signedToday(DateTime now, Map<int, DailyRecord> records) => records[now.day]?.signed == true;

/// 连续签到天数：从今天（未签则昨天）向前回数。
int currentStreak(DateTime now, Map<int, DailyRecord> records) {
  final days = <int>{
    for (final entry in records.entries)
      if (entry.value.signed == true) entry.key,
  };
  if (days.isEmpty) return 0;
  var cursor = days.contains(now.day) ? now.day : now.day - 1;
  var streak = 0;
  while (cursor >= 1 && days.contains(cursor)) {
    streak++;
    cursor--;
  }
  return streak;
}

/// 本轮 7 日周期进度：接口 currentProgress 为百分比字符串（如 "28.6%" ≈ 2/7），
/// 去掉 % 后按 x/100*7 四舍五入还原 0..7。
int cycleProgress(String currentProgress) {
  final percent = double.tryParse(currentProgress.trim().replaceAll('%', '')) ?? 0;
  return (percent / 100 * 7).round().clamp(0, 7);
}

/// 活动名去掉「{month}月·」类前缀，空串返回 null。
String? cleanEventName(String eventName, int month) {
  final cleaned = eventName.trim().replaceFirst(RegExp('^$month月[\\s·._\\-]*'), '').trim();
  return cleaned.isEmpty ? null : cleaned;
}
