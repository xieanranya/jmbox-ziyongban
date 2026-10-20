/// data 层仓库 Provider 集中定义。
///
/// repository 类保持纯 Dart（构造函数注入依赖）、不 import Riverpod；依赖组装全部
/// 收敛到本文件使关系一目了然；features / app 层只通过本文件暴露的 Provider 消费仓库。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/proxy_config.dart';
import 'models/config.dart';
import 'repositories/api_repository.dart';
import 'repositories/bookshelf_repository.dart';
import 'repositories/config_repository.dart';
import 'repositories/host_repository.dart';
import 'repositories/image_repository.dart';
import 'repositories/reading_history_repository.dart';
import 'repositories/search_history_repository.dart';

final configRepositoryProvider = Provider<ConfigRepository>((ref) => ConfigRepository());

final hostRepositoryProvider = Provider<HostRepository>((ref) => HostRepository());

/// 配置 → 代理配置：未启用或配置非法均为直连。
ProxyConfig _proxyFromConfig(AppConfig config) {
  if (!config.proxyEnabled) return const ProxyConfig.disabled();
  return ProxyConfig(enabled: true, host: config.proxyHost, port: config.proxyPort);
}

final apiRepositoryProvider = Provider<ApiRepository>((ref) {
  final repository = ApiRepository(
    ref.watch(hostRepositoryProvider).apiHost,
    proxy: _proxyFromConfig(ref.read(configRepositoryProvider).read()),
  );
  // 给域名仓库接上 /setting 回调（仓库刷新图片域名时经它拿服务端推荐主机；
  ref
      .read(hostRepositoryProvider)
      .setSettingFetcher(() async => (await repository.getSetting()).imageHost);
  return repository;
});

final imageRepositoryProvider = Provider<ImageRepository>((ref) {
  return ImageRepository(
    ref.watch(hostRepositoryProvider).imageHost,
    proxy: _proxyFromConfig(ref.read(configRepositoryProvider).read()),
  );
});

final bookshelfRepositoryProvider = Provider<BookshelfRepository>((ref) => BookshelfRepository());

final searchHistoryRepositoryProvider = Provider<SearchHistoryRepository>(
  (ref) => SearchHistoryRepository(),
);

final readingHistoryRepositoryProvider = Provider<ReadingHistoryRepository>(
  (ref) => ReadingHistoryRepository(),
);

