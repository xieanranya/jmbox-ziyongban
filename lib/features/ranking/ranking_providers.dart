/// 排行榜数据流：分类 chips + 排行分页（分类筛选接口按排序维度取榜）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../core/constants/sort.dart';
import '../../core/utils/paging.dart';
import '../../data/models/album.dart';
import '../../data/models/category.dart';
import '../../data/providers.dart';

/// 排行榜分类 chips（全部 + 一级分类）。
final rankingCategoriesProvider = FutureProvider.autoDispose<List<CategoryItem>>((ref) async {
  final info = await ref.watch(apiRepositoryProvider).getCategories();
  return info.categories;
});

/// 排行分页（family 参数 = "slug|排序名"；slug 空串表示全部）。
final rankingPagingProvider = Provider.autoDispose
    .family<PagingController<int, AlbumBrief>, String>((ref, queryKey) {
      final parts = queryKey.split('|');
      final slug = parts[0];
      final sort = CategorySort.values.firstWhere(
        (e) => e.name == (parts.length > 1 ? parts[1] : ''),
        orElse: () => CategorySort.totalRanking,
      );
      final api = ref.read(apiRepositoryProvider);
      final controller = pagingController((page) async {
        final info = await api.getCategoriesFilter(slug, page, sort);
        return (info.content, info.total);
      });
      ref.onDispose(controller.dispose);
      return controller;
    });
