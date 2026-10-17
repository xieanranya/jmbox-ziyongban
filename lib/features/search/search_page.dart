import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_routes.dart';
import '../../core/constants/dimen.dart';
import '../../data/models/category.dart';
import 'search_providers.dart';

/// 搜索页：胶囊输入框 + 历史记录 + 标签云板块（主题 / 角色 / 特殊PLAY / 其他）。
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // 进入即聚焦，直接可输入。
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 提交搜索：空串忽略；记录历史并跳结果页。
  Future<void> _submit(String raw) async {
    final keyword = raw.trim();
    if (keyword.isEmpty) return;
    await ref.read(searchHistoryProvider.notifier).add(keyword);
    if (!mounted) return;
    _focusNode.unfocus();
    context.push(AppRoutes.searchResult, extra: keyword);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final history = ref.watch(searchHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: Dimen.md),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            textInputAction: TextInputAction.search,
            onSubmitted: _submit,
            decoration: InputDecoration(
              isDense: true,
              hintText: '搜索漫画 / 作者',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _controller,
                builder: (context, value, _) => value.text.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _controller.clear();
                          _focusNode.requestFocus();
                        },
                      ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => _submit(_controller.text), child: const Text('搜索'))],
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(searchTagBlocksProvider);
          await ref.read(searchTagBlocksProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: Dimen.xl),
          children: [
            // 历史记录：chips 横排，右上角一键清空
            switch (history) {
              AsyncData(:final value) => _HistorySection(
                  keywords: value,
                  onTap: _submit,
                  onClear: () => ref.read(searchHistoryProvider.notifier).clear(),
                ),
              AsyncError() => const SizedBox.shrink(),
              _ => const SizedBox.shrink(),
            },
            const Divider(height: 1),
            const SizedBox(height: Dimen.sm),
            // 标签云板块：主题 / 角色 / 特殊PLAY / 其他
            ..._tagSections(),
          ],
        ),
      ),
    );
  }

  /// 标签云板块列表（接口 blocks；加载/失败时静默隐藏，不影响搜索本身）。
  List<Widget> _tagSections() {
    final blocks = ref.watch(searchTagBlocksProvider);
    return switch (blocks) {
      AsyncData(:final value) when value.isNotEmpty => [
          Padding(
            padding: const EdgeInsets.fromLTRB(Dimen.lg, Dimen.xs, Dimen.lg, 0),
            child: Text('板块', style: Theme.of(context).textTheme.titleSmall),
          ),
          for (final block in value) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(Dimen.lg, Dimen.md, Dimen.lg, Dimen.sm),
              child: Text(
                block.title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dimen.lg),
              child: Wrap(
                spacing: Dimen.sm,
                runSpacing: Dimen.sm,
                children: [
                  for (final tag in block.content)
                    ActionChip(
                      label: Text(tag),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _submit(tag),
                    ),
                ],
              ),
            ),
          ],
        ],
      _ => const [SizedBox.shrink()],
    };
  }
}

/// 历史记录区：chips 横排 + 右上角清空。
class _HistorySection extends StatelessWidget {
  const _HistorySection({
    required this.keywords,
    required this.onTap,
    required this.onClear,
  });

  final List<String> keywords;
  final ValueChanged<String> onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Dimen.lg, Dimen.md, Dimen.lg, Dimen.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('历史记录', style: Theme.of(context).textTheme.titleSmall),
              ),
              IconButton(
                tooltip: '清空历史',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 18),
                onPressed: onClear,
              ),
            ],
          ),
          if (keywords.isEmpty)
            Text('暂无搜索历史',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ))
          else
            Wrap(
              spacing: Dimen.sm,
              runSpacing: Dimen.sm,
              children: [
                for (final keyword in keywords)
                  ActionChip(
                    label: Text(keyword),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onTap(keyword),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
