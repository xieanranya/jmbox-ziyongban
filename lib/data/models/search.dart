/// 搜索模型。
library;

import '../../core/utils/json_utils.dart';
import 'album.dart';

class SearchInfo {
  const SearchInfo({
    required this.searchQuery,
    required this.total,
    required this.content,
    this.redirectAid,
  });

  factory SearchInfo.fromJson(Map<String, dynamic> json) => SearchInfo(
    searchQuery: json['search_query'] as String? ?? '',
    total: toInt(json['total']),
    content: toList(json['content'], AlbumBrief.fromJson),
    redirectAid: json['redirect_aid'] == null ? null : toInt(json['redirect_aid']),
  );

  final String searchQuery;
  final int total;
  final List<AlbumBrief> content;

  /// 按 JM 号搜索时返回的专辑 id；关键字搜索时为 null。
  final int? redirectAid;
}
