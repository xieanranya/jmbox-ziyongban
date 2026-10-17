/// 应用共享状态与启动初始化。
///
/// - [themeControllerProvider]：从 [configRepositoryProvider] 同步派生主题（read() 同步、
///   首帧即正确无闪烁），供 app 层 watch 驱动 `MaterialApp.themeMode`。
/// - [bootstrapProvider]：启动流程（应用域名 → 自动登录/签到），app 层据此做三态渲染 + 重试。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/theme.dart';
import '../core/network/host_probe.dart';
import '../data/providers.dart';
import '../data/repositories/host_repository.dart';
import '../data/session_providers.dart';

/// 主题模式控制器：初始值从配置同步派生，设置页切换时即时更新内存态。
class ThemeController extends Notifier<ThemeSetting> {
  @override
  ThemeSetting build() => ref.watch(configRepositoryProvider).read().themeSetting;

  /// 切换主题时即时更新内存态（持久化由 SettingsController 负责）。
  void update(ThemeSetting setting) {
    state = setting;
  }
}

final themeControllerProvider = NotifierProvider<ThemeController, ThemeSetting>(
  ThemeController.new,
);

final bootstrapProvider = FutureProvider<void>((ref) async {
  final configRepository = ref.watch(configRepositoryProvider);
  final hostRepository = ref.watch(hostRepositoryProvider);
  final apiRepository = ref.watch(apiRepositoryProvider);

  final config = configRepository.read();

  // API 域名：默认拉取最新域名列表；固定域名失效（不在列表）时回退第一台
  await hostRepository.refreshApiHosts();
  hostRepository.applyApiSelection(config.apiHost);

  // 图片域名：仓库内部调 /setting 拿推荐主机；auto → 推荐主机，手动 → 配置主机；
  // 失效/未拉到时回退列表第一台
  await hostRepository.refreshImageHosts();
  hostRepository.applyImageSelection(auto: config.imageAuto, host: config.imageHost);
  await _ensureAliveImageHost(hostRepository);

  // 已保存过凭据（登录成功即保存）则静默登录，失败不打扰用户
  if (config.username.isNotEmpty && config.password.isNotEmpty) {
    try {
      final user = await ref
          .read(sessionProvider.notifier)
          .signIn(config.username, config.password);
      if (config.autoCheckin) {
        try {
          final uid = '${user.uid}';
          final daily = await apiRepository.getDaily(uid);
          await apiRepository.checkDaily(uid, daily.dailyId);
        } catch (_) {
          // 签到失败静默，用户可手动去签到页
        }
      }
    } catch (_) {
      // 自动登录失败保持未登录态
    }
  }
});

/// API 主机探活：当前主机 4 秒内无 HTTP 响应 → 并发探测候选列表，
/// 固定到实测可用的最快一台；全部探活失败时保持原选路（交给请求重试）。
Future<void> _ensureAliveApiHost(HostRepository hostRepository) async {
  try {
    final current = hostRepository.apiHost();
    if (current != null && await probeHost(current)) return;
    final alive = await probeAliveHosts(hostRepository.apiHostList());
    if (alive.isNotEmpty) {
      hostRepository.applyApiSelection(alive.first);
    }
  } catch (_) {
    // 探活自身失败不影响启动，保持原选路
  }
}

/// 图片主机探活：语义同 [_ensureAliveApiHost]（手动固定语义，仅当内存选路失效时改 pin）。
Future<void> _ensureAliveImageHost(HostRepository hostRepository) async {
  try {
    final current = hostRepository.imageHost();
    if (current != null && await probeHost(current)) return;
    final alive = await probeAliveHosts(hostRepository.imageHostList());
    if (alive.isNotEmpty) {
      hostRepository.applyImageSelection(auto: false, host: alive.first);
    }
  } catch (_) {
    // 探活自身失败不影响启动，保持原选路
  }
}
