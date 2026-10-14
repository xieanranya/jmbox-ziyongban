/// 点赞模型。
library;

/// 点赞结果（单向操作，仅支持点赞一次、不支持取消）。
class LikeInfo {
  const LikeInfo({required this.status, required this.msg});

  factory LikeInfo.fromJson(Map<String, dynamic> json) =>
      LikeInfo(status: json['status'] as String? ?? '', msg: json['msg'] as String? ?? '');

  // 状态："success" / "error"
  final String status;
  final String msg;
}
