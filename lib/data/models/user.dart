/// 用户模型。
library;

import '../../core/utils/json_utils.dart';

/// 登录返回的用户信息。
class UserInfo {
  const UserInfo({
    required this.uid,
    required this.username,
    required this.email,
    required this.coin,
    required this.albumFavorites,
    required this.albumFavoritesMax,
    required this.levelName,
    required this.level,
    required this.nextLevelExp,
    required this.exp,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) => UserInfo(
    uid: toInt(json['uid']),
    username: json['username'] as String? ?? '',
    email: json['email'] as String? ?? '',
    coin: toInt(json['coin']),
    albumFavorites: toInt(json['album_favorites']),
    albumFavoritesMax: toInt(json['album_favorites_max']),
    levelName: json['level_name'] as String? ?? '',
    level: toInt(json['level']),
    nextLevelExp: toInt(json['nextLevelExp']),
    exp: toInt(json['exp']),
  );

  final int uid;
  final String username;
  final String email;
  final int coin;
  final int albumFavorites;
  final int albumFavoritesMax;
  final String levelName;
  final int level;
  final int nextLevelExp;
  final int exp;
}
