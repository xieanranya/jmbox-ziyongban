import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/storage/app_paths.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 解析并缓存数据目录（唯一异步 IO 前置）：此后路径均同步拼接，使主题等首帧状态可同步派生。
  await AppPaths.init();

  runApp(const ProviderScope(child: JmApp()));
}
