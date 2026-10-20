/// 详情页「介绍」「目录」Tab。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/constants/dimen.dart';
import '../../../data/models/album.dart';
import '../../history/history_providers.dart';
import '../album_detail_providers.dart';

/// 介绍 Tab：「简介」「标签」小节。
class IntroTab extends StatelessWidget {
  const IntroTab({super.key, required this.info});

  final AlbumDetail info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      // 底部多留 FAB 高度，避免内容末尾被「开始观看/继续阅读」遮挡。
      padding: const EdgeInsets.fromLTRB(Dimen.lg, Dimen.lg, Dimen.lg, Dimen.fabBottomInset),
      children: [
        Text('简介', style: theme.textTheme.titleSmall),
        const SizedBox(height: Dimen.sm),
        SelectableText(
          info.description.isEmpty ? '暂无简介' : info.description,
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.6, color: scheme.onSurfaceVariant),
        ),
        if (info.tags.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('标签', style: theme.textTheme.titleSmall),
          const SizedBox(height: Dimen.sm),
          Wrap(
            spacing: Dimen.sm,
            runSpacing: Dimen.sm,
            children: [
              for (final tag in info.tags)
                ActionChip(
                  label: Text(tag),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => context.push(AppRoutes.searchResult, extra: tag),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// 目录 Tab：章节按 sort 升序网格，点击进入阅读器并记录阅读历史。
class TocTab extends ConsumerWidget {
  const TocTab({super.key, required this.info});

  final AlbumDetail info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chapters = ref.watch(albumChaptersProvider(info.id));
    return GridView.builder(
      // 底部多留 FAB 高度，避免最后一话被「开始观看/继续阅读」遮挡。
      padding: const EdgeInsets.fromLTRB(Dimen.lg, Dimen.lg, Dimen.lg, Dimen.fabBottomInset),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        // 与首页网格共用列宽阈值，手机上同样排 3 列。
        maxCrossAxisExtent: Dimen.gridMinExtent,
        mainAxisExtent: 44,
        crossAxisSpacing: Dimen.sm,
        mainAxisSpacing: Dimen.sm,
      ),
      itemCount: chapters.length,
      itemBuilder: (context, index) {
        final chapter = chapters[index];
        final scheme = Theme.of(context).colorScheme;
        final radius = BorderRadius.circular(Dimen.rSm);
        // 底色放在 Material 上，InkWell 的 hover/splash 墨迹才能盖在底色之上显示。
        return Material(
          color: scheme.surfaceContainerHigh,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: radius,
            hoverColor: scheme.primary.withValues(alpha: 0.12),
            splashColor: scheme.primary.withValues(alpha: 0.2),
            onTap: () async {
              // 传专辑 id 与章节 id：阅读器用 getChapter 自行拿到全专辑 series。
              await recordAlbumView(ref, AlbumBrief.fromDetail(info));
              if (!context.mounted) return;
              await context.push('${AppRoutes.reader}/${info.id}/${chapter.id}');
              // 阅读器内换章会写进度，返回后刷新供详情页 FAB 判续读。
              ref.invalidate(albumReadingProgressProvider(info.id));
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dimen.sm),
              child: Center(
                child: Text(chapter.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
        );
      },
    );
  }
}
