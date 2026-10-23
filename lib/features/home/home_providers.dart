/// 首页数据流：浏览分区（promote）+ 分类标签（发现页迁入的 11 个选项）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../core/constants/sort.dart';
import '../../core/utils/paging.dart';
import '../../data/models/album.dart';
import '../../data/models/category.dart';
import '../../data/models/promote.dart';
import '../../data/providers.dart';

/// 首页标签：浏览分区（API promote）或分类（一级分类，内容走分类筛选 API）。
class HomeTab {
  const HomeTab({
    required this.key,
    required this.title,
    this.section,
    this.category,
  });

  /// 稳定 key：分区 "s:<id>"，分类 "c:<slug>"（跨刷新保留选中态）。
  final String key;
  final String title;

  /// 浏览分区（null 表示为分类标签）。
  final PromoteSection? section;

  /// 分类（null 表示为浏览分区）。
  final CategoryItem? category;

  bool get isCategory => category != null;
}

/// 组合标签顺序：浏览分区在前，分类在后；「最新A漫」插到「连载更新」正后方。
///
/// 匹配规则（保证安卓/iOS 两端排布一致，不依赖接口返回的精确标题）：
/// 1. 先找标题含「连载」或「更新」的分区（兼容 连载更新 / 连载中 / 更新中 等变体）；
/// 2. 找不到分区时再找同类分类（部分线路把连载更新放在分类里）；
/// 3. 都没有则紧跟第一个分区（没有分区就放最前），而不是丢到列表末尾。
List<HomeTab> buildHomeTabs(
  List<PromoteSection> sections,
  List<CategoryItem> categories,
) {
  final tabs = <HomeTab>[];
  for (final s in sections) {
    tabs.add(HomeTab(key: 's:${s.id}', title: s.title, section: s));
  }
  final rest = categories.toList();
  final latestIdx = rest.indexWhere((c) => c.name.contains('最新A漫'));
  if (latestIdx >= 0) {
    final latest = rest.removeAt(latestIdx);
    final at = tabs.indexWhere(_isSerialTab);
    tabs.insert(
      (at >= 0 ? at + 1 : (tabs.isNotEmpty ? 1 : 0)).clamp(0, tabs.length),
      HomeTab(key: 'c:${latest.slug}', title: latest.name, category: latest),
    );
  }
  for (final c in rest) {
    tabs.add(HomeTab(key: 'c:${c.slug}', title: c.name, category: c));
  }
  return tabs;
}

/// 是否为「连载更新」类标签（容忍标题变体与简繁体：连载更新/連載更新/連載中/更新中）。
/// 接口不同线路可能返回繁体文案，精确匹配会导致排布漂移（安卓/iOS 不一致）。
bool _isSerialTab(HomeTab tab) {
  final title = tab.title;
  // 「更新」简繁同形；「连载/連載」两种写法都认。
  return title.contains('连载') || title.contains('連載') || title.contains('更新');
}

/// 首页标签列表：浏览分区 + 分类（组合自 promote 与 categories 两个接口）。
final homeTabsProvider = FutureProvider.autoDispose<List<HomeTab>>((ref) async {
  final sections = await ref.watch(promoteSectionsProvider.future);
  final categories = await ref.watch(homeCategoriesProvider.future);
  return buildHomeTabs(sections, categories);
});

/// 浏览分区：getPromote 返回，仅保留 type=promote。
final promoteSectionsProvider = FutureProvider.autoDispose<List<PromoteSection>>((ref) async {
  final sections = await ref.watch(apiRepositoryProvider).getPromote();
  return sections.where((s) => s.sectionType == 'promote').toList();
});

/// 一级分类（发现页迁入首页的 11 个选项）。
final homeCategoriesProvider = FutureProvider.autoDispose<List<CategoryItem>>((ref) async {
  final info = await ref.watch(apiRepositoryProvider).getCategories();
  return info.categories;
});

/// 当前选中标签 key（"s:<id>" / "c:<slug>"）；null 表示默认第一个。
///
/// 用 provider 而非 widget state 持有：build 无副作用，下拉刷新可直接读取。
class SelectedHomeTab extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String key) => state = key;
}

final selectedHomeTabProvider = NotifierProvider<SelectedHomeTab, String?>(SelectedHomeTab.new);

/// 每个浏览分区的分页控制器（family 参数 = 分区 id）。
final homeSectionPagingProvider = Provider.autoDispose
    .family<PagingController<int, AlbumBrief>, int>((ref, sectionId) {
      final api = ref.read(apiRepositoryProvider);
      final controller = pagingController((page) async {
        // getPromoteList 的 page 从 0 起，内部页码从 1 起，需 -1。
        final info = await api.getPromoteList(sectionId, page - 1);
        return (info.list, info.total);
      });
      ref.onDispose(controller.dispose);
      return controller;
    });

/// 分类内容分页控制器（family 参数 = 查询 key "slug|子slug|排序名"）。
final categoryPagingProvider = Provider.autoDispose
    .family<PagingController<int, AlbumBrief>, String>((ref, queryKey) {
      final parts = queryKey.split('|');
      final slug = parts[0];
      final sub = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;
      final sort = CategorySort.values.firstWhere(
        (e) => e.name == (parts.length > 2 ? parts[2] : ''),
        orElse: () => CategorySort.latest,
      );
      final api = ref.read(apiRepositoryProvider);
      final controller = pagingController((page) async {
        // 子标签查询参数格式为「主标签_子标签」；页码约定与分类页一致（从 1 起）。
        final q = sub == null ? slug : '${slug}_$sub';
        final info = await api.getCategoriesFilter(q, page, sort);
        return (info.content, info.total);
      });
      ref.onDispose(controller.dispose);
      return controller;
    });
