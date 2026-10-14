/// 配置仓库：读写 config.json，内存缓存 + 磁盘持久化。
library;

import 'dart:convert';

import '../../core/constants/theme.dart';
import '../../core/storage/app_paths.dart';
import '../models/config.dart';

class ConfigRepository {
  ConfigRepository();

  AppConfig? _cache;

  AppConfig read() {
    final cached = _cache;
    if (cached != null) return cached;
    final file = AppPaths.config;
    if (!file.existsSync()) {
      const config = AppConfig();
      _writeToDisk(config);
      _cache = config;
      return config;
    }
    try {
      final config = AppConfig.fromJson(
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
      );
      _cache = config;
      return config;
    } catch (_) {
      const config = AppConfig();
      _cache = config;
      return config;
    }
  }

  bool updateWith({
    String? username,
    String? password,
    String? apiHost,
    bool? imageAuto,
    String? imageHost,
    bool? autoCheckin,
    ThemeSetting? themeSetting,
  }) {
    final latest = read();
    final updated = latest.copyWith(
      username: username,
      password: password,
      apiHost: apiHost,
      imageAuto: imageAuto,
      imageHost: imageHost,
      autoCheckin: autoCheckin,
      themeSetting: themeSetting,
    );
    _writeToDisk(updated);
    _cache = updated;
    return true;
  }

  void _writeToDisk(AppConfig config) {
    AppPaths.config.writeAsStringSync(jsonEncode(config.toJson()));
  }
}
