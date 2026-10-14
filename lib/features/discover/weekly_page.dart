/// 每周必看页：期数 × 类型。
///
/// 自持数据流：期数清单来自 [weekInfoProvider]，无需路由传参。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/filter_bar.dart';
import '../../shared/widgets/remote_grid_page.dart';
import '../../data/models/album.dart';
import '../../data/providers.dart';
import 'discover_providers.dart';

class WeeklyPage extends ConsumerStatefulWidget {
  const WeeklyPage({super.key});

  @override
  ConsumerState<WeeklyPage> createState() => _WeeklyPageState();
}

class _WeeklyPageState extends ConsumerState<WeeklyPage> {
  static const _weekTypes = [('hanman', '韩漫'), ('manga', '日漫'), ('another', '其他')];
  static final _periodRe = RegExp(r'第\d+期');

  /// 选中的期数；null 表示最新一期（期数加载后取第一项）。
  int? _categoryId;
  String _weekType = 'manga';

  /// 从 time 文本截取「第N期」。
  String _periodLabel(String time) {
    final match = _periodRe.firstMatch(time);
    return match?.group(0) ?? time;
  }

  @override
  Widget build(BuildContext context) {
    final periodsAsync = ref.watch(weekInfoProvider);

    return periodsAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('每周必看')),
        body: const LoadingView(),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('每周必看')),
        body: ErrorRetryView(error: error, onRetry: () => ref.invalidate(weekInfoProvider)),
      ),
      data: (info) {
        final periods = info.categories;
        if (periods.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('每周必看')),
            body: const EmptyView(message: '暂无期数数据'),
          );
        }
        final categoryId = _categoryId ?? periods.first.id;
        return RemoteGridPage(
          title: '每周必看',
          refreshKey: (categoryId, _weekType),
          filterBar: FilterBar(
            children: [
              FilterDropdown<String>(
                prefix: '期刊',
                value: '$categoryId',
                entries: [for (final p in periods) MapEntry('${p.id}', _periodLabel(p.time))],
                onChanged: (v) => setState(() => _categoryId = int.parse(v)),
              ),
              FilterDropdown<String>(
                prefix: '类型',
                value: _weekType,
                entries: [for (final (value, label) in _weekTypes) MapEntry(value, label)],
                onChanged: (v) => setState(() => _weekType = v),
              ),
            ],
          ),
          fetchPage: (page) async {
            // 该接口一次性返回整期内容，翻页返回空。
            if (page != 1) return (const <AlbumBrief>[], null);
            final list = await ref.read(apiRepositoryProvider).getWeekFilter(categoryId, _weekType);
            return (list, null);
          },
        );
      },
    );
  }
}
