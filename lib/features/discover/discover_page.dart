/// 发现页：每周入口 + 一级分类卡片网格 + blocks 标签云。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_routes.dart';
import '../../core/constants/dimen.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/section.dart';
import '../../data/models/category.dart';
import 'category_page.dart';
import 'discover_providers.dart';

class DiscoverPage extends ConsumerWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('发现')),
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(categoriesProvider);
          await ref.read(categoriesProvider.future);
        },
        child: categories.when(
          loading: () => const ScrollableStatusView(child: LoadingView()),
          error: (error, _) => ScrollableStatusView(
            child: ErrorRetryView(error: error, onRetry: () => ref.invalidate(categoriesProvider)),
          ),
          data: (info) => CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: _WeeklyEntries()),
              SliverPadding(
                padding: const EdgeInsets.all(Dimen.lg),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    // 手机上排 2 列，宽屏自动增列。
                    maxCrossAxisExtent: 160,
                    mainAxisExtent: 76,
                    crossAxisSpacing: Dimen.md,
                    mainAxisSpacing: Dimen.md,
                  ),
                  itemCount: info.categories.length,
                  itemBuilder: (context, index) => _CategoryCard(category: info.categories[index]),
                ),
              ),
              for (final block in info.blocks) ...[
                SliverToBoxAdapter(
                  child: SectionHeader(
                    block.title,
                    padding: const EdgeInsets.fromLTRB(Dimen.lg, Dimen.lg, Dimen.lg, Dimen.sm),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Dimen.lg),
                    child: Wrap(
                      spacing: Dimen.sm,
                      runSpacing: Dimen.sm,
                      children: [
                        for (final tag in block.content)
                          ActionChip(
                            label: Text(tag),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => context.push(AppRoutes.searchResult, extra: tag),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: Dimen.xl)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 每周入口区块：每周连载更新 + 每周必看。
class _WeeklyEntries extends StatelessWidget {
  const _WeeklyEntries();

  @override
  Widget build(BuildContext context) {
    final weekday = DateTime.now().weekday; // 1~7 周一~周日

    return Padding(
      padding: const EdgeInsets.fromLTRB(Dimen.lg, Dimen.lg, Dimen.lg, 0),
      child: Row(
        children: [
          Expanded(
            child: _EntryCard(
              icon: Icons.update,
              title: '每周连载更新',
              onTap: () => context.push(AppRoutes.serialization, extra: ('$weekday', '每周连载更新')),
            ),
          ),
          const SizedBox(width: Dimen.md),
          Expanded(
            child: _EntryCard(
              icon: Icons.calendar_month,
              title: '每周必看',
              // 期数数据由列表页自持加载。
              onTap: () => context.push(AppRoutes.weekly),
            ),
          ),
        ],
      ),
    );
  }
}

/// 每周入口卡片。
class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.icon, required this.title, required this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(Dimen.rMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Dimen.md),
          child: Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: Dimen.md),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category});

  final CategoryItem category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: () => context.push(
          AppRoutes.category,
          extra: CategoryQuery(
            slug: category.slug,
            title: category.name,
            subCategories: category.subCategories,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Dimen.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: Dimen.xs,
            children: [
              Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              if (category.subCategories.isNotEmpty)
                Text(
                  '${category.subCategories.length} 个子类',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
