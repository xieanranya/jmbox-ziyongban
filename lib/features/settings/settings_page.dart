/// 设置页：显示（主题）/ 账户和服务（自动签到、API 线路、图片源）/ 存储（清理缓存）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/dimen.dart';
import '../../core/constants/theme.dart';
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
                SectionCard(children: [_themeTile(context, ref, config)]),
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

// ---- 账户和服务 ----

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
