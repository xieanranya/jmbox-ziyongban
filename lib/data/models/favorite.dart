/// 收藏模型。
library;

import '../../core/utils/json_utils.dart';
import 'album.dart';

class FavoriteInfo {
  const FavoriteInfo({required this.total, required this.count, required this.list});

  factory FavoriteInfo.fromJson(Map<String, dynamic> json) => FavoriteInfo(
    total: toInt(json['total']),
    count: toInt(json['count']),
    list: toList(json['list'], AlbumBrief.fromJson),
  );

  final int total;
  final int count;
  final List<AlbumBrief> list;
}

/// 收藏/取消收藏共用同一接口的原始响应。
class FavoriteToggleResp {
  const FavoriteToggleResp({required this.status, required this.msg, required this.type});

  factory FavoriteToggleResp.fromJson(Map<String, dynamic> json) => FavoriteToggleResp(
    status: json['status'] as String? ?? '',
    msg: json['msg'] as String? ?? '',
    type: json['type'] as String? ?? '',
  );

  final String status;

  final String msg;

  /// 操作类型："add" / "remove"。
  final String type;
}
