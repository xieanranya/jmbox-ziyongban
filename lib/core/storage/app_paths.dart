/// 应用数据目录与持久化文件路径。
///
/// 目录路径是唯一异步来源（path_provider 平台通道），由 [AppPaths.init] 在 `runApp` 前解析一次；
/// 此后全部路径拼接为纯字符串操作、同步可用（供主题等首帧状态同步派生）。
/// 测试可直接为 [AppPaths.supportPath] 赋值临时目录注入。
library;

import 'dart:io';

import 'package:path_provider/path_provider.dart';

abstract final class AppPaths {
  /// 应用支持目录绝对路径。生产由 [init] 赋值一次；测试在 setUp 中直接赋值。
  /// 赋值前访问抛 [LateInitializationError]。
  static late String supportPath;

  /// 解析并缓存应用支持目录。必须在 `runApp` 前（main）调用一次。
  static Future<void> init() async {
    supportPath = (await getApplicationSupportDirectory()).path;
  }

  static File _file(String name) => File('$supportPath/$name');

  /// config.json（应用配置）。
  static File get config => _file('config.json');

  /// bookshelf.json（书架）。
  static File get bookshelf => _file('bookshelf.json');

  /// search_history.json（搜索历史）。
  static File get searchHistory => _file('search_history.json');

  /// history.json（阅读历史：看过啥）。
  static File get history => _file('history.json');

  /// progress.json（阅读历史：看到哪章）。
  static File get progress => _file('progress.json');

  /// images/（图片磁盘缓存根目录）。
  static Directory get images => Directory('$supportPath/images');
}
