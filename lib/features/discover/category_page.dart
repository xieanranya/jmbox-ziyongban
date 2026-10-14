/// 分类筛选页：主分类 × 子分类 × 排序。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/sort.dart';
import '../../shared/widgets/filter_bar.dart';
import '../../shared/widgets/remote_grid_page.dart';
import '../../data/models/category.dart';
import '../../data/providers.dart';

/// 分类列表查询参数（路由 extra）。
class CategoryQuery {
  const CategoryQuery({
    required this.slug,
    required this.title,
    this.subSlug,
    this.sort = CategorySort.latest,
    this.subCategories = const [],
  });

  final String slug;
  final String title;

  /// 子分类 slug；null 表示「全部」。
  final String? subSlug;
  final CategorySort sort;

  /// 子分类清单（仅筛选栏展示用，入参后不变，不参与 ==）。
  final List<CategorySub> subCategories;

  CategoryQuery copyWith({String? subSlug, CategorySort? sort}) => CategoryQuery(
    slug: slug,
    title: title,
    subSlug: subSlug ?? this.subSlug,
    sort: sort ?? this.sort,
    subCategories: subCategories,
  );

  @override
  bool operator ==(Object other) =>
      other is CategoryQuery &&
      other.slug == slug &&
      other.title == title &&
      other.subSlug == subSlug &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(slug, title, subSlug, sort);
}

class CategoryPage extends ConsumerStatefulWidget {
  const CategoryPage({super.key, required this.query});

  final CategoryQuery query;

  @override
  ConsumerState<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends ConsumerState<CategoryPage> {
  late CategoryQuery _query = widget.query;

  @override
  void didUpdateWidget(CategoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 路由复用同一实例时同步外部传入的查询。
    if (oldWidget.query != widget.query) {
      setState(() => _query = widget.query);
    }
  }

  void _update(CategoryQuery query) => setState(() => _query = query);

  @override
  Widget build(BuildContext context) {
    final query = _query;
    return RemoteGridPage(
      title: query.title,
      refreshKey: query,
      filterBar: FilterBar(
        children: [
          FilterDropdown<String>(
            prefix: '分类',
            value: query.subSlug ?? '',
            entries: [
              const MapEntry('', '全部'),
              for (final c in query.subCategories) MapEntry(c.slug, c.name),
            ],
            // copyWith 无法区分「未传」和「显式传 null」，必须重建。
            onChanged: (v) => _update(
              CategoryQuery(
                slug: query.slug,
                title: query.title,
                subSlug: v.isEmpty ? null : v,
                sort: query.sort,
                subCategories: query.subCategories,
              ),
            ),
          ),
          FilterDropdown<String>(
            prefix: '排序',
            value: query.sort.name,
            entries: [for (final e in categorySortLabels.entries) MapEntry(e.key.name, e.value)],
            onChanged: (v) =>
                _update(query.copyWith(sort: CategorySort.values.firstWhere((e) => e.name == v))),
          ),
        ],
      ),
      fetchPage: (page) async {
        // 子标签查询参数格式为「主标签_子标签」。
        final q = _query;
        final info = await ref
            .read(apiRepositoryProvider)
            .getCategoriesFilter(
              q.subSlug == null ? q.slug : '${q.slug}_${q.subSlug}',
              page,
              q.sort,
            );
        return (info.content, info.total);
      },
    );
  }
}
