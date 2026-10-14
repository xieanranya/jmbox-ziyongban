/// 设置项控制器：读改写全部经 [ConfigRepository]，写成功后刷新内存态。
///
/// 各设置项的运行时生效（主题切换、域名选路）也在本层完成；
/// 页面只负责取选项与触发选中。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_state.dart';
import '../../core/constants/theme.dart';
import '../../data/models/config.dart';
import '../../data/providers.dart';
import '../../data/session_providers.dart';

class SettingsController extends AsyncNotifier<AppConfig> {
  @override
  AppConfig build() => ref.read(configRepositoryProvider).read();

  /// 主题模式：先经主题控制器即时生效（内存态），再持久化。
  Future<bool> setThemeSetting(ThemeSetting value) {
    ref.read(themeControllerProvider.notifier).update(value);
    return _set(() => ref.read(configRepositoryProvider).updateWith(themeSetting: value));
  }

  Future<bool> setAutoCheckin(bool value) =>
      _set(() => ref.read(configRepositoryProvider).updateWith(autoCheckin: value));

  /// 应用 API 域名选择：先经 HostRepository 生效，再持久化。
  /// 换机后旧会话必失效，故带凭据时在新域名上重新登录。
  Future<bool> applyApiHost(String value) async {
    ref.read(hostRepositoryProvider).applyApiSelection(value);
    final ok = await _set(() => ref.read(configRepositoryProvider).updateWith(apiHost: value));
    final config = ref.read(configRepositoryProvider).read();
    if (config.username.isNotEmpty && config.password.isNotEmpty) {
      try {
        await ref.read(sessionProvider.notifier).signIn(config.username, config.password);
      } catch (_) {
        // 重登失败不影响换路结果，用户可手动重新登录。
      }
    }
    return ok;
  }

  /// 应用图片域名选择（空串 = 跟随服务配置）：先经 HostRepository 生效，再持久化。
  Future<bool> applyImageHost(String value) async {
    ref.read(hostRepositoryProvider).applyImageSelection(auto: value.isEmpty, host: value);
    return _set(
      () => ref
          .read(configRepositoryProvider)
          .updateWith(imageAuto: value.isEmpty, imageHost: value.isNotEmpty ? value : null),
    );
  }

  /// 每次获取都刷新一次（拉最新域名，与 bootstrap 一致）；失败沿用现有列表。
  Future<List<String>> fetchApiHosts() async {
    final hostRepository = ref.read(hostRepositoryProvider);
    try {
      await hostRepository.refreshApiHosts();
    } catch (_) {}
    return hostRepository.apiHostList();
  }

  /// 每次获取都刷新一次（推荐主机由仓库内部调 /setting，与 bootstrap 一致）
  Future<List<String>> fetchImageHosts() async {
    final hostRepository = ref.read(hostRepositoryProvider);
    final config = ref.read(configRepositoryProvider).read();
    try {
      await hostRepository.refreshImageHosts();
    } catch (_) {}
    // 拉取失败时内部推荐主机为旧值/null：auto 落到队首（上次推荐或内置），
    // 手动则固定 config 值，均与 bootstrap 的回退语义一致。
    hostRepository.applyImageSelection(auto: config.imageAuto, host: config.imageHost);
    return hostRepository.imageHostList();
  }

  Future<bool> _set(bool Function() action) async {
    final ok = action();
    if (ok) {
      state = AsyncData(ref.read(configRepositoryProvider).read());
    }
    return ok;
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsController, AppConfig>(
  SettingsController.new,
);

/// 图片缓存总大小（字节）。
final imageCacheSizeProvider = FutureProvider.autoDispose<int>((ref) {
  return ref.watch(imageRepositoryProvider).totalSize();
});
