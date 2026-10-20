/// 详情页固定头部：封面 + 车号/作者/章节/页数 信息行。
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/constants/dimen.dart';
import '../../../core/utils/format.dart';
import '../../../shared/widgets/album_card.dart';
import '../../../data/models/album.dart';

class DetailHeader extends StatelessWidget {
  const DetailHeader({super.key, required this.info});

  final AlbumDetail info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.all(Dimen.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: 'cover-${info.id}',
            child: SizedBox(
              width: 120,
              child: AspectRatio(
                aspectRatio: Dimen.coverAspectRatio,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CoverImage(albumId: info.id),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: Dimen.sm,
              children: [
                _InfoRow(
                  label: '车号',
                  child: Text('JM${info.id}', style: _valueStyle(theme)),
                ),
                _InfoRow(
                  // 作者可点击，跳转搜索结果。
                  label: '作者',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 2,
                    children: [
                      for (final author in info.author)
                        InkWell(
                          borderRadius: BorderRadius.circular(4),
                          onTap: () => context.push(AppRoutes.searchResult, extra: author),
                          child: Text(author, style: _valueStyle(theme, color: scheme.primary)),
                        ),
                    ],
                  ),
                ),
                _InfoRow(
                  label: '章节',
                  child: Text('${info.series.length} 话', style: _valueStyle(theme)),
                ),
                _InfoRow(
                  label: '页数',
                  child: Text('${info.totalPhotos} 页', style: _valueStyle(theme)),
                ),
                _InfoRow(
                  label: '更新',
                  child: Text(formatDate(info.addtime), style: _valueStyle(theme)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static TextStyle? _valueStyle(ThemeData theme, {Color? color}) {
    return theme.textTheme.bodyMedium?.copyWith(color: color);
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        SizedBox(width: 48, child: Text(label, style: labelStyle)),
        Expanded(child: child),
      ],
    );
  }
}
