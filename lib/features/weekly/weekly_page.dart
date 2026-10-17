/// 每周必看：期数选择（日历表格式期数列表面板）+ 日漫/其他/韩漫三板块 + 整期网格。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/dimen.dart';
import '../../data/models/week.dart';
import '../../shared/widgets/album_card.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/grid_utils.dart';
import 'weekly_providers.dart';

class WeeklyPage extends ConsumerStatefulWidget {
  const WeeklyPage({super.key});

  @override
  ConsumerState<WeeklyPage> createState() => _WeeklyPageState();
}

class _WeeklyPageState extends ConsumerState<WeeklyPage> {
  /// 选中期号 id；null 表示默认最新一期。
  String? _issueId;

  /// 选中板块 id；null 表示默认第一个（日漫）。
  String? _typeId;

  @override
  Widget build(BuildContext context) {
    final info = ref.watch(weekInfoProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('每周必看')),
      body: info.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ScrollableStatusView(
          child: ErrorRetryView(
            error: error,
            onRetry: () => ref.invalidate(weekInfoProvider),
          ),
        ),
        data: (week) {
          final issues = week.categories;
          if (issues.isEmpty) {
            return const ScrollableStatusView(
              child: EmptyView(message: '暂无期数', icon: Icons.event_busy_outlined),
            );
          }
          final issueId = _issueId ?? issues.first.id;
          final issueTime = issues
              .firstWhere((i) => i.id == issueId, orElse: () => issues.first)
              .time;
          final types = week.orderedType;
          final typeId = _typeId ?? types.first.id;

          return Column(
            children: [
              // 期数选择行（日历表格式面板入口）
              InkWell(
                onTap: () => _showIssuePicker(week, issueId),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Dimen.lg, vertical: Dimen.md),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        issueTime,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: Dimen.xs),
                      Icon(Icons.arrow_drop_down,
                          size: 22, color: colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
              // 三板块 Tab：日漫 / 其他 / 韩漫
              _TypeTabs(
                types: types,
                selectedId: typeId,
                onSelected: (id) => setState(() => _typeId = id),
              ),
              const Divider(height: 1),
              // 内容网格（整期一次返回）
              Expanded(
                child: _WeekContent(issueId: issueId, typeId: typeId),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 期数选择面板（日历表格式：两列宫格，选中描边）。
  Future<void> _showIssuePicker(WeekInfo week, String currentId) async {
    final colorScheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surfaceContainerLow,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.75,
            ),
            padding: const EdgeInsets.fromLTRB(Dimen.lg, Dimen.md, Dimen.lg, Dimen.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('选择期数',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface)),
                const SizedBox(height: Dimen.md),
                Flexible(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: Dimen.sm,
                      mainAxisSpacing: Dimen.sm,
                      childAspectRatio: 3.4,
                    ),
                    itemCount: week.categories.length,
                    itemBuilder: (ctx, index) {
                      final issue = week.categories[index];
                      final selected = issue.id == currentId;
                      return InkWell(
                        borderRadius: BorderRadius.circular(Dimen.rSm),
                        onTap: () {
                          setState(() => _issueId = issue.id);
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: Dimen.sm),
                          decoration: BoxDecoration(
                            color: selected
                                ? colorScheme.primaryContainer
                                : colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(Dimen.rSm),
                            border: Border.all(
                              color: selected
                                  ? colorScheme.primary
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            issue.time,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  selected ? FontWeight.w600 : FontWeight.w400,
                              color: selected
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 三板块 Tab：选中项加粗 + 下划线指示器（参考图样式）。
class _TypeTabs extends StatelessWidget {
  const _TypeTabs({
    required this.types,
    required this.selectedId,
    required this.onSelected,
  });

  final List<WeekType> types;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 46,
      child: Row(
        children: [
          for (final t in types)
            Expanded(
              child: InkWell(
                onTap: () => onSelected(t.id),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      t.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: t.id == selectedId
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: t.id == selectedId
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // 选中下划线
                    Container(
                      width: 24,
                      height: 3,
                      decoration: BoxDecoration(
                        color: t.id == selectedId
                            ? colorScheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 某一期某一板块的内容网格。
class _WeekContent extends ConsumerWidget {
  const _WeekContent({required this.issueId, required this.typeId});

  final String issueId;
  final String typeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(weekContentProvider(WeekQuery(issueId, typeId)));
    return content.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ScrollableStatusView(
        child: ErrorRetryView(
          error: error,
          onRetry: () => ref.invalidate(weekContentProvider),
        ),
      ),
      data: (weekList) {
        if (weekList.list.isEmpty) {
          return const ScrollableStatusView(
            child: EmptyView(message: '本期暂无内容', icon: Icons.inbox_outlined),
          );
        }
        return RefreshIndicator.adaptive(
          onRefresh: () async {
            ref.invalidate(weekContentProvider);
            await ref.read(weekContentProvider(WeekQuery(issueId, typeId)).future);
          },
          child: LayoutBuilder(
            builder: (context, constraints) => GridView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(Dimen.lg),
              gridDelegate:
                  albumGridDelegate(constraints.maxWidth - Dimen.lg * 2),
              itemCount: weekList.list.length,
              itemBuilder: (context, index) =>
                  AlbumCard(album: weekList.list[index]),
            ),
          ),
        );
      },
    );
  }
}
