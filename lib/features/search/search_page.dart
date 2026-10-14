import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_routes.dart';
import '../../core/constants/dimen.dart';
import '../../shared/widgets/async_view.dart';
import 'search_providers.dart';

/// 搜索页：胶囊输入框 + 历史列表；提交记录历史并跳结果页。
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
      body: switch (history) {
        AsyncData(:final value) =>
          value.isEmpty
              ? const EmptyView(message: '暂无搜索历史', icon: Icons.history)
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: Dimen.sm),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(Dimen.lg, Dimen.xs, Dimen.sm, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('搜索历史', style: Theme.of(context).textTheme.titleSmall),
                          ),
                          IconButton(
                            tooltip: '清空历史',
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () => ref.read(searchHistoryProvider.notifier).clear(),
                          ),
                        ],
                      ),
                    ),
                    for (final keyword in value)
                      ListTile(
                        leading: Icon(Icons.history, color: scheme.outline),
                        title: Text(keyword, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          icon: Icon(Icons.close, size: 18, color: scheme.outline),
                          onPressed: () => ref.read(searchHistoryProvider.notifier).remove(keyword),
                        ),
                        onTap: () => _submit(keyword),
                      ),
                  ],
                ),
        AsyncError() => const SizedBox.shrink(),
        _ => const LoadingView(),
      },
    );
  }
}
