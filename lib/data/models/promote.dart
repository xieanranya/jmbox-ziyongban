/// 首页推荐模型。
library;

import '../../core/utils/json_utils.dart';
import 'album.dart';

/// 清洗分区标题：去掉运营追加的箭头提示后缀，如「連載更新→右滑看更多→」→「連載更新」。
/// 从首个箭头（→ ➡ » ›）处截断并去空白。仅本文件 fromJson 使用，故库私有。
String _cleanSectionTitle(String title) {
  final index = title.indexOf(RegExp(r'[→➡»›]'));
  return (index < 0 ? title : title.substring(0, index)).trim();
}

class PromoteSection {
  const PromoteSection({
    required this.id,
    required this.title,
    required this.slug,
    required this.sectionType,
    required this.content,
  });

  factory PromoteSection.fromJson(Map<String, dynamic> json) => PromoteSection(
    id: toInt(json['id']),
    title: _cleanSectionTitle(json['title'] as String? ?? ''),
    slug: json['slug'] as String? ?? '',
    sectionType: json['type'] as String? ?? '',
    content: toList(json['content'], AlbumBrief.fromJson),
  );

  final int id;
  final String title;
  final String slug;
  final String sectionType;
  final List<AlbumBrief> content;
}

/// 分组下的分页专辑列表。
class PromoteList {
  const PromoteList({required this.total, required this.list});

  factory PromoteList.fromJson(Map<String, dynamic> json) =>
      PromoteList(total: toInt(json['total']), list: toList(json['list'], AlbumBrief.fromJson));

  final int total;
  final List<AlbumBrief> list;
}
