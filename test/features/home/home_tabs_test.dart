/// 首页标签排序单测：保证「最新A漫」稳定插到「连载更新」类标签之后，
/// 且简繁体/标题变体/缺失分区三种情况都不漂移（安卓与 iOS 排布一致）。
///
/// 运行：flutter test test/features/home/home_tabs_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:jmbox/data/models/category.dart';
import 'package:jmbox/data/models/promote.dart';
import 'package:jmbox/features/home/home_providers.dart';

PromoteSection _section(String title) => PromoteSection(
  id: title.hashCode.abs() % 1000,
  title: title,
  slug: title,
  sectionType: 'promote',
  content: const [],
);

CategoryItem _category(String name) => CategoryItem(
  id: name.hashCode.abs() % 1000,
  name: name,
  slug: name,
  totalAlbums: 0,
  subCategories: const [],
);

List<String> _titles(List<HomeTab> tabs) => tabs.map((t) => t.title).toList();

void main() {
  group('buildHomeTabs 排序', () {
    test('简体「连载更新」：最新A漫紧随其后', () {
      final tabs = buildHomeTabs(
        [_section('推荐'), _section('连载更新')],
        [_category('最新A漫'), _category('同人')],
      );
      expect(_titles(tabs), ['推荐', '连载更新', '最新A漫', '同人']);
    });

    test('繁体「連載更新」：同样紧随其后（跨线路字型差异不再漂移）', () {
      final tabs = buildHomeTabs(
        [_section('推荐'), _section('連載更新')],
        [_category('最新A漫'), _category('同人')],
      );
      expect(_titles(tabs), ['推荐', '連載更新', '最新A漫', '同人']);
    });

    test('标题变体「連載中」：也能匹配', () {
      final tabs = buildHomeTabs(
        [_section('推荐'), _section('連載中')],
        [_category('最新A漫')],
      );
      expect(_titles(tabs), ['推荐', '連載中', '最新A漫']);
    });

    test('没有连载分区：置于第一个分区之后（不再丢到末尾）', () {
      final tabs = buildHomeTabs(
        [_section('推荐'), _section('完结')],
        [_category('最新A漫'), _category('同人')],
      );
      expect(_titles(tabs), ['推荐', '最新A漫', '完结', '同人']);
    });

    test('完全没有分区：最新A漫排最前', () {
      final tabs = buildHomeTabs(
        const [],
        [_category('最新A漫'), _category('同人')],
      );
      expect(_titles(tabs), ['最新A漫', '同人']);
    });

    test('没有最新A漫分类：原样拼接', () {
      final tabs = buildHomeTabs(
        [_section('推荐')],
        [_category('同人')],
      );
      expect(_titles(tabs), ['推荐', '同人']);
    });
  });
}
