/// 设置页：显示（主题 / 画质增强）/ 网络（代理 / 诊断）/ 账户和服务（自动签到、API 线路、图片源）/ 存储（清理缓存）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/dimen.dart';
import '../../core/constants/enhance.dart';
import '../../core/constants/theme.dart';
import '../../core/network/host_probe.dart';
import '../../core/network/proxy_config.dart';
import '../../core/utils/host.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/section.dart';
import '../../data/models/config.dart';
import '../../data/providers.dart';
import 'settings_providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(settingsProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: config == null
          ? const LoadingView()
          : ListView(
              padding: const EdgeInsets.only(bottom: Dimen.xl),
              children: [
                const SectionHeader('显示'),
                SectionCard(
                  children: [
                    _themeTile(context, ref, config),
                    const Divider(height: 1, indent: Dimen.lg, endIndent: Dimen.lg),
                    _enhanceTile(context, ref, config),
                  ],
                ),
                const SectionHeader('网络'),
                SectionCard(
                  children: [
                    SwitchListTile(
                      title: const Text('代理模式'),
                      subtitle: const Text('经 HTTP 代理访问 API 与图片（Clash/v2ray 混合端口）'),
                      value: config.proxyEnabled,
                      onChanged: (v) => _save(
                        context,
                        ref.read(settingsProvider.notifier).setProxy(enabled: v),
                      ),
                    ),
                    if (config.proxyEnabled) ...[
                      const Divider(height: 1, indent: Dimen.lg, endIndent: Dimen.lg),
                      ListTile(
                        leading: const Icon(Icons.vpn_lock_outlined),
                        title: const Text('代理地址'),
                        subtitle: Text(config.proxyDisplay),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showProxyDialog(context, ref),
                      ),
                    ],
                    const Divider(height: 1, indent: Dimen.lg, endIndent: Dimen.lg),
                    ListTile(
                      leading: const Icon(Icons.network_check_outlined),
                      title: const Text('网络诊断'),
                      subtitle: const Text('测试各 API / 图片域名当前网络下的可达性'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _runNetworkDiagn(context, ref),
                    ),
                  ],
                ),
                const SectionHeader('账户和服务'),
                SectionCard(
                  children: [
                    SwitchListTile(
                      title: const Text('自动签到'),
                      subtitle: const Text('登录成功后自动执行每日签到'),
                      value: config.autoCheckin,
                      onChanged: (v) =>
                          _save(context, ref.read(settingsProvider.notifier).setAutoCheckin(v)),
                    ),
                    const Divider(height: 1, indent: Dimen.lg, endIndent: Dimen.lg),
                    ListTile(
                      title: const Text('线路与图源'),
                      subtitle: const Text('选择 API 线路和图片源'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showHostDialog(context),
                    ),
                  ],
                ),
                const SectionHeader('存储'),
                SectionCard(children: [_clearCacheTile(context, ref)]),
              ],
            ),
    );
  }

  // ---- 显示 ----

  Widget _themeTile(BuildContext context, WidgetRef ref, AppConfig config) {
    return ListTile(
      title: const Text('主题'),
      trailing: SegmentedButton<ThemeSetting>(
        showSelectedIcon: false,
        style: const ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        segments: const [
          ButtonSegment(value: ThemeSetting.system, label: Text('系统')),
          ButtonSegment(value: ThemeSetting.light, label: Text('白天')),
          ButtonSegment(value: ThemeSetting.dark, label: Text('黑夜')),
        ],
        selected: {config.themeSetting},
        onSelectionChanged: (selection) =>
            _save(context, ref.read(settingsProvider.notifier).setThemeSetting(selection.first)),
      ),
    );
  }

  /// 画质增强档位：弹窗四选一，保存后阅读器即时生效。
  Widget _enhanceTile(BuildContext context, WidgetRef ref, AppConfig config) {
    final level = config.enhanceLevel;
    return ListTile(
      leading: const Icon(Icons.auto_awesome),
      title: const Text('画质增强'),
      subtitle: Text('${level.label} · ${level.description}'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showEnhanceDialog(context, ref),
    );
  }

  Future<void> _showEnhanceDialog(BuildContext context, WidgetRef ref) async {
    final current = ref.read(settingsProvider).value?.enhanceLevel ?? EnhanceLevel.off;
    final picked = await showDialog<EnhanceLevel>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('画质增强（超级分辨率）'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final level in EnhanceLevel.values)
              ListTile(
                leading: Icon(_enhanceIcon(level)),
                title: Text(level.label),
                subtitle: Text(level.description),
                trailing: level == current
                    ? Icon(Icons.check, color: Theme.of(dialogContext).colorScheme.primary)
                    : null,
                onTap: () => Navigator.pop(dialogContext, level),
              ),
            const SizedBox(height: Dimen.sm),
            Text(
              '经典档在后台线程完成，原图先显示、增强后平滑替换；「超级」较吃性能。'
              '「AI 超分」内置 Real-ESRGAN 模型逐块推理，每页约数秒、排队处理，'
              '低端设备建议用「标准」。',
              style: Theme.of(dialogContext).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')),
        ],
      ),
    );
    if (picked != null && picked != current) {
      if (!context.mounted) return;
      _save(context, ref.read(settingsProvider.notifier).setEnhanceLevel(picked));
    }
  }

  // ---- 网络：代理 ----

  Future<void> _showProxyDialog(BuildContext context, WidgetRef ref) =>
      showDialog<void>(context: context, builder: (_) => const _ProxyDialog());

  // ---- 网络：诊断 ----

  /// 网络诊断：对当前生效的全部 API/图片域名计时探活（遵守当前代理设置）。
  Future<void> _runNetworkDiagn(BuildContext context, WidgetRef ref) async {
    final config = ref.read(settingsProvider).value ?? const AppConfig();
    final proxy = config.proxyEnabled
        ? ProxyConfig(enabled: true, host: config.proxyHost, port: config.proxyPort)
        : const ProxyConfig.disabled();
    final hostRepo = ref.read(hostRepositoryProvider);
    final hosts = <String>{...hostRepo.apiHostList(), ...hostRepo.imageHostList()}.toList();

    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)),
            SizedBox(width: Dimen.lg),
            Text('正在诊断…'),
          ],
        ),
      ),
    );

    final results = await Future.wait([
      for (final host in hosts)
        probeHostDetailed(host, proxy: proxy).then((r) => (host: host, alive: r.$1, ms: r.$2)),
    ]);

    if (!context.mounted) return;
    Navigator.pop(context); // 关「正在诊断」
    final aliveCount = results.where((r) => r.alive).length;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('诊断结果 $aliveCount/${results.length}'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  proxy.enabled ? '经代理 ${proxy.display}' : '当前为直连',
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                ),
                const SizedBox(height: Dimen.sm),
                for (final r in results)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Icon(
                          r.alive ? Icons.check_circle : Icons.error,
                          size: 16,
                          color: r.alive
                              ? Theme.of(dialogContext).colorScheme.primary
                              : Theme.of(dialogContext).colorScheme.error,
                        ),
                        const SizedBox(width: Dimen.sm),
                        Expanded(child: Text(_hostLabel(r.host), style: Theme.of(dialogContext).textTheme.bodySmall)),
                        Text(
                          r.alive ? '${r.ms} ms' : '不可达',
                          style: Theme.of(dialogContext).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: Dimen.sm),
                Text(
                  '全部不可达时：直连网络被拦截，请开启代理模式；'
                  '代理模式下仍全部不可达，请检查代理软件端口。',
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('关闭'))],
      ),
    );
  }

  // ---- 账户和服务 ----

  Future<void> _showHostDialog(BuildContext context) =>
      showDialog<void>(context: context, builder: (_) => const _HostDialog());

  // ---- 存储 ----

  Widget _clearCacheTile(BuildContext context, WidgetRef ref) {
    final size = ref.watch(imageCacheSizeProvider);
    return ListTile(
      leading: const Icon(Icons.cleaning_services_outlined),
      title: const Text('清理图片缓存'),
      subtitle: size.when(
        loading: () => const Text('统计中…'),
        error: (_, _) => const Text('大小统计失败'),
        data: (value) => Text(formatBytes(value)),
      ),
      onTap: () => _confirmClear(context, ref),
    );
  }

  /// 清理图片缓存：弹确认对话框 → 删除缓存目录 → 刷新大小。
  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清理图片缓存'),
        content: const Text('将删除所有已缓存的封面与章节图片，需要时会重新下载。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('清理'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(imageRepositoryProvider).clearCache();
    ref.invalidate(imageCacheSizeProvider);
  }
}

/// 线路与图源选择弹窗：API 线路（固定一台）+ 图片源（跟随服务/手动）。
///
/// API 不提供「自动」选项：运行期主机冻结（会话按域名签发，换机必 401），
/// 自动选路只发生在 bootstrap 取第一台；这里把当前生效的那台高亮为选中。
class _HostDialog extends ConsumerStatefulWidget {
  const _HostDialog();

  @override
  ConsumerState<_HostDialog> createState() => _HostDialogState();
}

class _HostDialogState extends ConsumerState<_HostDialog> {
  List<String> _apiHosts = const [];
  List<String> _imageHosts = const [];

  SettingsController get _notifier => ref.read(settingsProvider.notifier);

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final notifier = ref.read(settingsProvider.notifier);
    final (apiHosts, imageHosts) = (
      await notifier.fetchApiHosts(),
      await notifier.fetchImageHosts(),
    );
    if (!mounted) return;
    setState(() {
      _apiHosts = apiHosts;
      _imageHosts = imageHosts;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = ref.watch(settingsProvider).value;
    final sectionTitleStyle = theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500);
    // 固定域名失效（空或不在列表）时生效的是第一台（见 applyApiSelection）。
    final savedApiHost = config?.apiHost ?? '';
    final effectiveApiHost = savedApiHost.isNotEmpty && _apiHosts.contains(savedApiHost)
        ? savedApiHost
        : (_apiHosts.isNotEmpty ? _apiHosts.first : null);

    return AlertDialog(
      title: const Text('线路与图源', textAlign: TextAlign.center),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '选择线路后立即生效。',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Dimen.md),
              SectionHeader(
                'API 线路',
                padding: const EdgeInsets.only(bottom: Dimen.xs),
                style: sectionTitleStyle,
              ),
              for (final host in _apiHosts)
                _option(
                  context,
                  title: _hostLabel(host),
                  checked: host == effectiveApiHost,
                  onTap: () => _save(context, _notifier.applyApiHost(host)),
                ),
              const SizedBox(height: Dimen.md),
              SectionHeader(
                '图片源',
                padding: const EdgeInsets.only(bottom: Dimen.xs),
                style: sectionTitleStyle,
              ),
              _option(
                context,
                title: '跟随服务配置',
                subtitle: '自动使用平台当前推荐图片源',
                checked: config == null || config.imageAuto,
                onTap: () => _save(context, _notifier.applyImageHost('')),
              ),
              for (final host in _imageHosts)
                _option(
                  context,
                  title: _hostLabel(host),
                  checked: config != null && !config.imageAuto && config.imageHost == host,
                  onTap: () => _save(context, _notifier.applyImageHost(host)),
                ),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭'))],
    );
  }

  Widget _option(
    BuildContext context, {
    required String title,
    String? subtitle,
    required bool checked,
    required VoidCallback onTap,
  }) => ListTile(
    dense: true,
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle),
    trailing: checked ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
    onTap: onTap,
  );
}

/// 代理编辑弹窗：主机/端口 + 常用预设 + 测试当前线路（保存前不落盘）。
class _ProxyDialog extends ConsumerStatefulWidget {
  const _ProxyDialog();

  @override
  ConsumerState<_ProxyDialog> createState() => _ProxyDialogState();
}

class _ProxyDialogState extends ConsumerState<_ProxyDialog> {
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    final config = ref.read(settingsProvider).value ?? const AppConfig();
    _hostController = TextEditingController(text: config.proxyHost);
    _portController = TextEditingController(text: '${config.proxyPort}');
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  ProxyConfig get _draft => ProxyConfig(
    enabled: true,
    host: _hostController.text.trim(),
    port: int.tryParse(_portController.text.trim()) ?? 0,
  );

  Future<void> _test(BuildContext context) async {
    final draft = _draft;
    if (!draft.valid) {
      _toast(context, '地址或端口不合法');
      return;
    }
    setState(() => _testing = true);
    final hostRepo = ref.read(hostRepositoryProvider);
    final apiHost = hostRepo.apiHost();
    final imageHost = hostRepo.imageHost();
    final targets = <String>[?apiHost, ?imageHost];
    final alive = await Future.wait([
      for (final host in targets) probeHostDetailed(host, proxy: draft).then((r) => r.$1),
    ]);
    if (!context.mounted) return;
    setState(() => _testing = false);
    final ok = alive.isNotEmpty && alive.every((v) => v);
    _toast(context, ok ? '代理连接正常（${draft.display}）' : '代理连接失败，请检查地址端口与代理软件');
  }

  Future<void> _save(BuildContext context) async {
    final draft = _draft;
    if (!draft.valid) {
      _toast(context, '地址或端口不合法');
      return;
    }
    final ok = await ref
        .read(settingsProvider.notifier)
        .setProxy(enabled: true, host: draft.host.trim(), port: draft.port);
    if (!context.mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      _toast(context, '保存失败，请重试');
    }
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('代理地址'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '仅支持 HTTP 代理（CONNECT）。Clash 类软件的「混合端口」即可；'
              'SOCKS 代理 Dart 网络层不支持。',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: Dimen.md),
            TextField(
              controller: _hostController,
              decoration: const InputDecoration(labelText: '主机', hintText: '127.0.0.1'),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: Dimen.sm),
            TextField(
              controller: _portController,
              decoration: const InputDecoration(labelText: '端口', hintText: '7890'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: Dimen.md),
            Wrap(
              spacing: Dimen.sm,
              children: [
                for (final (host, port, label) in [
                  ProxyPresets.clash,
                  ProxyPresets.clashVerge,
                  ProxyPresets.v2rayN,
                  ProxyPresets.generic,
                ])
                  ActionChip(
                    label: Text('$label\n$host:$port'),
                    onPressed: () {
                      _hostController.text = host;
                      _portController.text = '$port';
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _testing ? null : () => _test(context),
          child: _testing ? const Text('测试中…') : const Text('测试连接'),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(onPressed: () => _save(context), child: const Text('保存')),
      ],
    );
  }
}

/// 执行持久化；失败提示（状态保持旧值）。
Future<void> _save(BuildContext context, Future<bool> action) async {
  if (await action) return;
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存失败，请重试')));
}

/// 域名展示：去掉协议前缀，空值显示「自动」。
String _hostLabel(String host) {
  final stripped = stripScheme(host);
  return stripped.isEmpty ? '自动' : stripped;
}

/// 画质增强档位图标（与阅读器内快捷切换一致）。
IconData _enhanceIcon(EnhanceLevel level) => switch (level) {
  EnhanceLevel.off => Icons.image_outlined,
  EnhanceLevel.standard => Icons.auto_fix_normal,
  EnhanceLevel.strong => Icons.auto_awesome,
  EnhanceLevel.ultra => Icons.auto_awesome_mosaic,
  EnhanceLevel.ai => Icons.psychology,
};
