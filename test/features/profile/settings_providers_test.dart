import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jmbox/app/app_state.dart';
import 'package:jmbox/core/constants/app_constants.dart';
import 'package:jmbox/core/constants/theme.dart';
import 'package:jmbox/core/storage/app_paths.dart';
import 'package:jmbox/data/providers.dart';
import 'package:jmbox/data/repositories/config_repository.dart';
import 'package:jmbox/data/repositories/host_repository.dart';
import 'package:jmbox/features/settings/settings_providers.dart';

void main() {
  late Directory tempDir;
  late ConfigRepository config;
  late HostRepository hosts;
  late ProviderContainer container;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('jmbox_settings_provider_test_');
    AppPaths.supportPath = tempDir.path;
    config = ConfigRepository();
    hosts = HostRepository();
    container = ProviderContainer(
      overrides: [
        configRepositoryProvider.overrideWithValue(config),
        hostRepositoryProvider.overrideWithValue(hosts),
      ],
    );
    await container.read(settingsProvider.future);
  });

  tearDown(() async {
    container.dispose();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('主题与自动签到同时更新运行态、Provider 状态和磁盘配置', () async {
    final notifier = container.read(settingsProvider.notifier);
    expect(await notifier.setThemeSetting(ThemeSetting.dark), isTrue);
    expect(await notifier.setAutoCheckin(true), isTrue);

    expect(container.read(themeControllerProvider), ThemeSetting.dark);
    expect(container.read(settingsProvider).value?.autoCheckin, isTrue);
    final reloaded = ConfigRepository().read();
    expect(reloaded.themeSetting, ThemeSetting.dark);
    expect(reloaded.autoCheckin, isTrue);
  });

  test('图片主机选择同时更新运行态与配置', () async {
    final selected = kDefaultImageHosts[1];
    expect(await container.read(settingsProvider.notifier).applyImageHost(selected), isTrue);

    expect(hosts.imageHost(), selected);
    expect(config.read().imageAuto, isFalse);
    expect(config.read().imageHost, selected);

    expect(await container.read(settingsProvider.notifier).applyImageHost(''), isTrue);
    expect(config.read().imageAuto, isTrue);
  });
}
