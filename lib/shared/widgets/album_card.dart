/// 专辑卡片：3:4 封面 + 名称(2行) + 作者(1行)，点击进入详情页。
///
/// 使用方：PagedCardGrid、LocalGridPage。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/dimen.dart';
import '../../core/constants/app_routes.dart';
import '../../data/models/album.dart';
import '../../data/providers.dart';

class AlbumCard extends StatelessWidget {
  const AlbumCard({super.key, required this.album, this.heroTag, this.onTap});

  final AlbumBrief album;

  /// Hero 标签（列表→详情转场）；null 则不包 Hero。
  final Object? heroTag;

  /// 为 null 时默认进入详情页。
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final cover = ClipRRect(
      borderRadius: BorderRadius.circular(Dimen.rMd),
      child: AspectRatio(
        aspectRatio: Dimen.coverAspectRatio,
        child: CoverImage(albumId: album.id),
      ),
    );

    return InkWell(
      borderRadius: BorderRadius.circular(Dimen.rMd),
      onTap: onTap ?? () => context.push('${AppRoutes.albumDetail}/${album.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: Dimen.xs,
        children: [
          heroTag == null ? cover : Hero(tag: heroTag!, child: cover),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dimen.xs),
              child: Text(
                album.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium,
              ),
            ),
          ),
          if (album.author.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dimen.xs),
              child: Text(
                album.author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

/// 封面文件名：`{id}_3x4.jpg`（3:4 比例版本）。
String _coverImageName(int albumId) => '${albumId}_3x4.jpg';

/// 专辑封面图：经 ImageRepository 取缓存文件显示，失败显示破图图标。
class CoverImage extends ConsumerStatefulWidget {
  const CoverImage({super.key, required this.albumId});

  final int albumId;

  @override
  ConsumerState<CoverImage> createState() => _CoverImageState();
}

class _CoverImageState extends ConsumerState<CoverImage> {
  File? _file;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.albumId != widget.albumId) {
      _file = null;
      _failed = false;
      _load();
    }
  }

  Future<void> _load() async {
    final albumId = widget.albumId;
    try {
      final file = await ref.read(imageRepositoryProvider).getCover(_coverImageName(albumId));
      if (!mounted || widget.albumId != albumId) return;
      setState(() => _file = file);
    } catch (e) {
      if (!mounted || widget.albumId != albumId) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    Widget child;
    if (_failed || file == null) {
      child = _failed ? const BrokenImageIcon() : const SizedBox.shrink();
    } else {
      child = LayoutBuilder(
        builder: (context, constraints) => Image.file(
          file,
          fit: BoxFit.cover,
          // 限制解码尺寸，降低内存峰值。
          cacheWidth: (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context)).round(),
          frameBuilder: (context, child, frame, wasSyncLoaded) =>
              frame == null ? const SizedBox.shrink() : child,
          errorBuilder: (context, error, stackTrace) => const BrokenImageIcon(),
        ),
      );
    }

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: child,
    );
  }
}

/// 破图图标：封面加载失败时的占位。
class BrokenImageIcon extends StatelessWidget {
  const BrokenImageIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.broken_image_outlined,
      size: 40,
      color: Theme.of(context).colorScheme.outline,
    );
  }
}
