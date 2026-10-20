import 'package:flutter_test/flutter_test.dart';
import 'package:jmbox/data/models/daily.dart';
import 'package:jmbox/features/profile/checkin/checkin_logic.dart';

DailyRecord _record(String date, {bool? signed = true, bool bonus = false}) =>
    DailyRecord(date: date, signed: signed, bonus: bonus);

void main() {
  group('签到记录索引', () {
    test('按月内日期索引，同一天多条取最后一条', () {
      final first = _record('2026-09-03', signed: false);
      final last = _record('2026-09-03', bonus: true);
      final info = DailyInfo(
        dailyId: 1,
        threeDaysCoin: '',
        threeDaysExp: '',
        sevenDaysCoin: '',
        sevenDaysExp: '',
        eventName: '',
        currentProgress: '',
        record: [
          [first],
          [last, _record('invalid')],
        ],
      );
      final indexed = recordsOf(info);
      expect(indexed.keys, [3]);
      expect(identical(indexed[3], last), isTrue);
    });
  });

  group('月历', () {
    test('周一开头并补齐 42 格，映射签到、奖励和今天', () {
      final cells = monthCells(DateTime(2026, 9, 4), {
        3: _record('03'),
        4: _record('04', bonus: true),
      });
      expect(cells, hasLength(42));
      expect(cells.take(1).map((cell) => cell.day), [null]);
      final day3 = cells.singleWhere((cell) => cell.day == 3);
      final day4 = cells.singleWhere((cell) => cell.day == 4);
      expect(day3.signed, isTrue);
      expect(day3.today, isFalse);
      expect(day4.today, isTrue);
      expect(day4.bonus, isTrue);
    });

    test('今日签到状态与连续天数覆盖已签和未签两种起点', () {
      final now = DateTime(2026, 9, 5);
      final signed = {3: _record('03'), 4: _record('04'), 5: _record('05')};
      expect(signedToday(now, signed), isTrue);
      expect(currentStreak(now, signed), 3);

      final notSignedToday = {2: _record('02'), 3: _record('03'), 4: _record('04')};
      expect(signedToday(now, notSignedToday), isFalse);
      expect(currentStreak(now, notSignedToday), 3);
      expect(currentStreak(now, const {}), 0);
    });
  });

  test('周期百分比还原为 0..7 并夹取越界', () {
    expect(cycleProgress('28.6%'), 2);
    expect(cycleProgress('100%'), 7);
    expect(cycleProgress('999%'), 7);
    expect(cycleProgress('bad'), 0);
  });

  test('活动名移除当月前缀并处理空结果', () {
    expect(cleanEventName('9月 · 秋日签到', 9), '秋日签到');
    expect(cleanEventName('其他活动', 9), '其他活动');
    expect(cleanEventName('9月·', 9), isNull);
  });
}
