/// 专辑模型。
library;

import '../../core/utils/json_utils.dart';

/// 列表页通用条目。
class AlbumBrief {
  const AlbumBrief({required this.id, required this.name, required this.author});

  factory AlbumBrief.fromJson(Map<String, dynamic> json) => AlbumBrief(
    id: toInt(json['id']),
    name: json['name'] as String? ?? '',
    author: json['author'] as String? ?? '',
  );

  /// 从详情提取（作者多值合并为一串，与历史/书架条目一致）。
  AlbumBrief.fromDetail(AlbumDetail detail)
    : id = detail.id,
      name = detail.name,
      author = detail.author.join(' ');

  final int id;
  final String name;
  final String author;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'author': author};
}

class Series {
  const Series({required this.id, required this.name, required this.sort});

  factory Series.fromJson(Map<String, dynamic> json) => Series(
    id: toInt(json['id']),
    name: json['name'] as String? ?? '',
    sort: json['sort'] as String? ?? '',
  );

  final int id;
  final String name;
  final String sort;
}

class AlbumDetail {
  const AlbumDetail({
    required this.id,
    required this.name,
    required this.author,
    required this.description,
    required this.tags,
    required this.totalPhotos,
    required this.addtime,
    required this.totalViews,
    required this.likes,
    required this.series,
    required this.commentTotal,
    required this.liked,
    required this.isFavorite,
  });

  factory AlbumDetail.fromJson(Map<String, dynamic> json) => AlbumDetail(
    id: toInt(json['id']),
    name: json['name'] as String? ?? '',
    author: toStringList(json['author']),
    description: json['description'] as String? ?? '',
    tags: toStringList(json['tags']),
    totalPhotos: toInt(json['total_photos']),
    addtime: json['addtime'] as String? ?? '',
    totalViews: toInt(json['total_views']),
    likes: toInt(json['likes']),
    series: toList(json['series'], Series.fromJson),
    commentTotal: toInt(json['comment_total']),
    liked: json['liked'] as bool? ?? false,
    isFavorite: json['is_favorite'] as bool? ?? false,
  );

  final int id;
  final String name;
  final List<String> author;
  final String description;
  final List<String> tags;
  final int totalPhotos;
  final String addtime;
  final int totalViews;
  final int likes;
  final List<Series> series;
  final int commentTotal;
  final bool liked;
  final bool isFavorite;

  /// 新增字段时只需在此补一处，调用方不会漏传。
  AlbumDetail copyWith({List<Series>? series}) => AlbumDetail(
    id: id,
    name: name,
    author: author,
    description: description,
    tags: tags,
    totalPhotos: totalPhotos,
    addtime: addtime,
    totalViews: totalViews,
    likes: likes,
    series: series ?? this.series,
    commentTotal: commentTotal,
    liked: liked,
    isFavorite: isFavorite,
  );
}

/// 章节的页面图片列表（getChapter 返回）。
class Chapter {
  const Chapter({required this.id, required this.series, required this.images});

  factory Chapter.fromJson(Map<String, dynamic> json) => Chapter(
    id: toInt(json['id']),
    series: toList(json['series'], Series.fromJson),
    images: toStringList(json['images']),
  );

  final int id;
  final List<Series> series;
  final List<String> images;

  /// 新增字段时只需在此补一处，调用方不会漏传。
  Chapter copyWith({List<Series>? series}) =>
      Chapter(id: id, series: series ?? this.series, images: images);
}
