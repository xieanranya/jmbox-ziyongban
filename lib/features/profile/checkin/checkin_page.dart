/// 每日签到页：活动标题 → 签到日历 → 7 日奖励进度 → 签到按钮。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/dimen.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../data/models/daily.dart';
import '../../../data/providers.dart';
import '../../../data/session_providers.dart';
import 'checkin_logic.dart';
import 'checkin_providers.dart';

class CheckinPage extends ConsumerWidget {
  const CheckinPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('每日签到')),
      body: user == null ? const SizedBox.shrink() : _CheckinBody(userId: '${user.uid}'),
    );
  }
}

class _CheckinBody extends ConsumerWidget {
  const _CheckinBody({required this.userId});

  final String userId;

  Future<void> _sign(BuildContext context, WidgetRef ref, DailyInfo info) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref.read(apiRepositoryProvider).checkDaily(userId, info.dailyId);
      ref.invalidate(dailyProvider(userId));
      messenger.showSnackBar(SnackBar(content: Text(result.msg)));
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('签到失败：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daily = ref.watch(dailyProvider(userId));

    return RefreshIndicator.adaptive(
      onRefresh: () => ref.refresh(dailyProvider(userId).future),
      child: daily.when(
        loading: () => const LoadingView(),
        error: (error, _) =>
            ErrorRetryView(error: error, onRetry: () => ref.invalidate(dailyProvider(userId))),
        data: (info) {
          final now = DateTime.now();
          final records = recordsOf(info);
          final cells = monthCells(now, records);
          final streak = currentStreak(now, records);
          final progress = cycleProgress(info.currentProgress);
          final todaySigned = signedToday(now, records);

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(Dimen.lg, Dimen.lg, Dimen.lg, Dimen.xl + Dimen.xs),
            children: [
              _Title(info: info, now: now, streak: streak),
              const SizedBox(height: Dimen.xl),
              _Calendar(cells: cells),
              const SizedBox(height: Dimen.xl),
              _RewardCard(info: info, progress: progress),
              const SizedBox(height: Dimen.xl),
              FilledButton(
                onPressed: todaySigned ? null : () => _sign(context, ref, info),
                child: Text(todaySigned ? '今日已签到' : '签到'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 标题：「8月 · 同人祭」+「已连续签到 N 天」。
class _Title extends StatelessWidget {
  const _Title({required this.info, required this.now, required this.streak});

  final DailyInfo info;
  final DateTime now;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cleaned = cleanEventName(info.eventName, now.month);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          cleaned == null ? '${now.month}月' : '${now.month}月 · $cleaned',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        Text(
          '已连续签到 $streak 天',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// 当月日历：周一开头；今日主色底、已签 ✓、奖励日 ♥ 角标。
class _Calendar extends StatelessWidget {
  const _Calendar({required this.cells});

  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

  final List<CalendarCell> cells;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(
          children: [
            for (final label in _weekdays)
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var i = 0; i < cells.length; i += 7)
          Row(
            children: [
              for (final cell in cells.sublist(i, i + 7))
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Padding(padding: const EdgeInsets.all(2), child: _cell(context, cell)),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _cell(BuildContext context, CalendarCell cell) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background = cell.today
        ? scheme.primary.withValues(alpha: 0.14)
        : cell.signed
        ? scheme.surfaceContainerHighest
        : null;
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(Dimen.rSm), color: background),
      child: cell.day == null
          ? null
          : Stack(
              children: [
                Center(child: Text('${cell.day}', style: theme.textTheme.labelMedium)),
                if (cell.signed)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Icon(Icons.check, size: 12, color: scheme.primary),
                  ),
                if (cell.bonus)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Icon(Icons.favorite, size: 11, color: scheme.primary),
                  ),
              ],
            ),
    );
  }
}

/// 本轮连续签到奖励卡：进度条 + 第 3/7 天里程碑。
class _RewardCard extends StatelessWidget {
  const _RewardCard({required this.info, required this.progress});

  final DailyInfo info;
  final int progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Dimen.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '本轮连续签到奖励',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                Text(
                  '$progress/7',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: progress / 7, minHeight: 8),
            ),
            const SizedBox(height: Dimen.lg),
            _Milestone(
              day: 3,
              coin: info.threeDaysCoin,
              exp: info.threeDaysExp,
              achieved: progress >= 3,
            ),
            const SizedBox(height: Dimen.md),
            _Milestone(
              day: 7,
              coin: info.sevenDaysCoin,
              exp: info.sevenDaysExp,
              achieved: progress >= 7,
            ),
          ],
        ),
      ),
    );
  }
}

/// 第 N 天里程碑行：左侧达成态方块（✓），右侧奖励文案。
class _Milestone extends StatelessWidget {
  const _Milestone({
    required this.day,
    required this.coin,
    required this.exp,
    required this.achieved,
  });

  final int day;
  final String coin;
  final String exp;
  final bool achieved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Dimen.rSm),
            color: achieved
                ? scheme.primary.withValues(alpha: 0.16)
                : scheme.surfaceContainerHighest,
          ),
          alignment: Alignment.center,
          child: achieved
              ? Icon(Icons.check, size: 18, color: scheme.primary)
              : Text(
                  '$day',
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
                ),
        ),
        const SizedBox(width: Dimen.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('连续签到 $day 天', style: theme.textTheme.bodyMedium),
              Text(
                '$coin 金币 + $exp 经验',
                style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
