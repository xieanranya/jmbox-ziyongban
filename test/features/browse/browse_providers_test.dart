import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jmbox/data/models/album.dart';
import 'package:jmbox/data/models/category.dart';
import 'package:jmbox/data/models/promote.dart';
import 'package:jmbox/data/models/week.dart';
import 'package:jmbox/data/providers.dart';
import 'package:jmbox/data/repositories/api_repository.dart';
import 'package:jmbox/features/discover/discover_providers.dart';
import 'package:jmbox/features/home/home_providers.dart';

class _FakeApiRepository extends ApiRepository {
  _FakeApiRepository() : super(() => null);

  @override
  Future<List<PromoteSection>> getPromote() async => const [
    PromoteSection(id: 1, title: '推荐', slug: 'a', sectionType: 'promote', content: []),
    PromoteSection(id: 2, title: '广告', slug: 'b', sectionType: 'ad', content: []),
  ];

  @override
  Future<PromoteList> getPromoteList(int id, int page) async => PromoteList(
    total: 1,
    list: [AlbumBrief(id: page, name: '第$page页', author: '$id')],
  );

  @override
  Future<CategoryInfo> getCategories() async => const CategoryInfo(
    categories: [CategoryItem(id: 1, name: '主题', slug: 'topic', totalAlbums: 2, subCategories: [])],
    blocks: [],
  );

  @override
  Future<WeekInfo> getWeekInfo() async => const WeekInfo(
    categories: [WeekCategory(id: 1, title: '本周', time: '2026-09')],
    weekTypes: [WeekType(id: 'manga', title: '漫画')],
  );
}

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [apiRepositoryProvider.overrideWithValue(_FakeApiRepository())],
    );
  });

  tearDown(() => container.dispose());

  test('首页只保留 promote 类型分区', () async {
    final sections = await container.read(promoteSectionsProvider.future);
    expect(sections.map((section) => section.id), [1]);
  });

  test('首页选中分区状态可更新', () {
    expect(container.read(selectedSectionIdProvider), isNull);
    container.read(selectedSectionIdProvider.notifier).select(9);
    expect(container.read(selectedSectionIdProvider), 9);
  });

  test('发现页分类 Provider 透传仓库结果', () async {
    final info = await container.read(categoriesProvider.future);
    expect(info.categories.single.slug, 'topic');
  });

  test('发现页每周 Provider 透传仓库结果', () async {
    final info = await container.read(weekInfoProvider.future);
    expect(info.categories.single.title, '本周');
    expect(info.weekTypes.single.id, 'manga');
  });
}
