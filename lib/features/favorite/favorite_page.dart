/// 漫画收藏列表页（需登录态）：排序。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/sort.dart';
import '../../shared/widgets/filter_bar.dart';
import '../../shared/widgets/remote_grid_page.dart';
import '../../data/providers.dart';

class FavoritePage extends ConsumerStatefulWidget {
  const FavoritePage({super.key});

  @override
  ConsumerState<FavoritePage> createState() => _FavoritePageState();
}

class _FavoritePageState extends ConsumerState<FavoritePage> {
  FavoriteSort _sort = FavoriteSort.favoriteTime;

  @override
  Widget build(BuildContext context) {
    return RemoteGridPage(
      title: '漫画收藏',
      refreshKey: _sort,
      filterBar: FilterBar(
        children: [
          FilterDropdown<String>(
            prefix: '排序',
            value: _sort.name,
            entries: [for (final e in favoriteSortLabels.entries) MapEntry(e.key.name, e.value)],
            onChanged: (v) => setState(() {
              _sort = FavoriteSort.values.firstWhere((e) => e.name == v);
            }),
          ),
        ],
      ),
      fetchPage: (page) async {
        final info = await ref.read(apiRepositoryProvider).getFavorite(0, page, _sort);
        return (info.list, info.total);
      },
    );
  }
}
