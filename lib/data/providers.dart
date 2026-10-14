/// data 层仓库 Provider 集中定义。
///
/// repository 类保持纯 Dart（构造函数注入依赖）、不 import Riverpod；依赖组装全部
/// 收敛到本文件使关系一目了然；features / app 层只通过本文件暴露的 Provider 消费仓库。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repositories/api_repository.dart';
import 'repositories/bookshelf_repository.dart';
import 'repositories/config_repository.dart';
import 'repositories/host_repository.dart';
import 'repositories/image_repository.dart';
import 'repositories/reading_history_repository.dart';
import 'repositories/search_history_repository.dart';

final configRepositoryProvider = Provider<ConfigRepository>((ref) => ConfigRepository());

final hostRepositoryProvider = Provider<HostRepository>((ref) => HostRepository());

final apiRepositoryProvider = Provider<ApiRepository>((ref) {
  final repository = ApiRepository(ref.watch(hostRepositoryProvider).apiHost);
  // 给域名仓库接上 /setting 回调（仓库刷新图片域名时经它拿服务端推荐主机；
  ref
      .read(hostRepositoryProvider)
      .setSettingFetcher(() async => (await repository.getSetting()).imageHost);
  return repository;
});

final imageRepositoryProvider = Provider<ImageRepository>((ref) {
  return ImageRepository(ref.watch(hostRepositoryProvider).imageHost);
});

final bookshelfRepositoryProvider = Provider<BookshelfRepository>((ref) => BookshelfRepository());

final searchHistoryRepositoryProvider = Provider<SearchHistoryRepository>(
  (ref) => SearchHistoryRepository(),
);

final readingHistoryRepositoryProvider = Provider<ReadingHistoryRepository>(
  (ref) => ReadingHistoryRepository(),
);
