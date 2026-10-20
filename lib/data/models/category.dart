/// 分类模型。
library;

import '../../core/utils/json_utils.dart';

class CategorySub {
  const CategorySub({required this.id, required this.name, required this.slug});

  factory CategorySub.fromJson(Map<String, dynamic> json) => CategorySub(
    id: toInt(json['CID']),
    name: json['name'] as String? ?? '',
    slug: json['slug'] as String? ?? '',
  );

  final int id;
  final String name;
  final String slug;

  @override
  bool operator ==(Object other) =>
      other is CategorySub && other.id == id && other.name == name && other.slug == slug;

  @override
  int get hashCode => Object.hash(id, name, slug);
}

class CategoryItem {
  const CategoryItem({
    required this.id,
    required this.name,
    required this.slug,
    required this.totalAlbums,
    required this.subCategories,
  });

  factory CategoryItem.fromJson(Map<String, dynamic> json) => CategoryItem(
    id: toInt(json['id']),
    name: json['name'] as String? ?? '',
    slug: json['slug'] as String? ?? '',
    totalAlbums: toInt(json['total_albums']),
    subCategories: toList(json['sub_categories'], CategorySub.fromJson),
  );

  final int id;
  final String name;
  final String slug;
  final int totalAlbums;
  final List<CategorySub> subCategories;
}

class CategoryBlock {
  const CategoryBlock({required this.title, required this.content});

  factory CategoryBlock.fromJson(Map<String, dynamic> json) =>
      CategoryBlock(title: json['title'] as String? ?? '', content: toStringList(json['content']));

  final String title;
  final List<String> content;
}

class CategoryInfo {
  const CategoryInfo({required this.categories, required this.blocks});

  factory CategoryInfo.fromJson(Map<String, dynamic> json) => CategoryInfo(
    categories: toList(json['categories'], CategoryItem.fromJson),
    blocks: toList(json['blocks'], CategoryBlock.fromJson),
  );

  final List<CategoryItem> categories;
  final List<CategoryBlock> blocks;
}
