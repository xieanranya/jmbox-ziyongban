/// 搜索结果列表页：关键词 × 排序。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/sort.dart';
import '../../shared/widgets/filter_bar.dart';
import '../../shared/widgets/remote_grid_page.dart';
import '../../data/providers.dart';

class SearchResultPage extends ConsumerStatefulWidget {
  const SearchResultPage({super.key, required this.keyword});

  final String keyword;

  @override
  ConsumerState<SearchResultPage> createState() => _SearchResultPageState();
}

class _SearchResultPageState extends ConsumerState<SearchResultPage> {
  SearchSort _sort = SearchSort.latest;

  @override
  Widget build(BuildContext context) {
    return RemoteGridPage(
      title: widget.keyword,
      refreshKey: _sort,
      filterBar: FilterBar(
        children: [
          FilterDropdown<String>(
            prefix: '排序',
            value: _sort.name,
            entries: [for (final e in searchSortLabels.entries) MapEntry(e.key.name, e.value)],
            onChanged: (v) => setState(() {
              _sort = SearchSort.values.firstWhere((e) => e.name == v);
            }),
          ),
        ],
      ),
      fetchPage: (page) async {
        final info = await ref.read(apiRepositoryProvider).search(widget.keyword, page, _sort);
        return (info.content, info.total);
      },
    );
  }
}
