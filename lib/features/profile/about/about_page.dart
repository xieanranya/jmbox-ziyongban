/// 关于页：项目地址（复制到剪贴板）+ 开源许可。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/dimen.dart';
import '../../../shared/widgets/section.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  /// GitHub 仓库地址（不直接展示，仅用于复制）。
  static const String _repoUrl = 'https://github.com/Eter-Nights/JmBox';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Dimen.xl),
        children: [
          // ---- 应用标识 ----
          Padding(
            padding: const EdgeInsets.fromLTRB(0, Dimen.xl, 0, Dimen.lg),
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(Dimen.rMd),
                  ),
                  child: Icon(
                    Icons.auto_stories_outlined,
                    size: 44,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: Dimen.md),
                Text('JmBox', style: theme.textTheme.titleLarge),
              ],
            ),
          ),
          const SectionHeader('项目'),
          SectionCard(
            children: [
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('项目地址'),
                trailing: const Icon(Icons.copy_rounded, size: 20),
                onTap: () => _copyRepo(context),
              ),
            ],
          ),
          const SectionHeader('许可'),
          SectionCard(
            children: [
              ListTile(
                leading: const Icon(Icons.gavel_outlined),
                title: const Text('开源许可'),
                trailing: Text(
                  'MIT',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _copyRepo(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _repoUrl));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('仓库地址已复制'), duration: Duration(seconds: 2)));
  }
}
