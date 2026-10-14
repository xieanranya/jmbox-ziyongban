/// 评论模型。
library;

import '../../core/utils/json_utils.dart';

/// 主评论与嵌套回复共用同一结构。
class CommentInfo {
  const CommentInfo({
    required this.cid,
    required this.username,
    required this.content,
    required this.addtime,
    required this.replys,
  });

  factory CommentInfo.fromJson(Map<String, dynamic> json) => CommentInfo(
    cid: toInt(json['CID']),
    username: json['username'] as String? ?? '',
    content: _stripContentDiv(json['content'] as String? ?? ''),
    addtime: json['addtime'] as String? ?? '',
    replys: toList(json['replys'], CommentInfo.fromJson),
  );

  final int cid;
  final String username;
  final String content;
  final String addtime;
  final List<CommentInfo> replys;
}

class CommentList {
  const CommentList({required this.total, required this.list});

  factory CommentList.fromJson(Map<String, dynamic> json) =>
      CommentList(total: toInt(json['total']), list: toList(json['list'], CommentInfo.fromJson));

  final int total;
  final List<CommentInfo> list;
}

class CommentPost {
  const CommentPost({required this.msg, required this.status});

  factory CommentPost.fromJson(Map<String, dynamic> json) =>
      CommentPost(msg: json['msg'] as String? ?? '', status: json['status'] as String? ?? '');

  /// 结果消息：成功为「评论成功发布!...」，失败为具体原因。
  final String msg;

  /// 状态："ok"/"fail"。
  final String status;
}

/// 剥掉评论正文的 `<div ...>...</div>` 包裹标签。
String _stripContentDiv(String content) {
  if (!content.startsWith('<div') || !content.endsWith('</div>')) {
    return content;
  }
  final body = content.substring(4, content.length - 6);
  final gt = body.indexOf('>');
  return gt < 0 ? content : body.substring(gt + 1);
}
