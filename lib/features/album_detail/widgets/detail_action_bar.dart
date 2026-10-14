/// 详情页四按钮区：观看数 / 喜欢 / 收藏 / 书架。
///
/// 点击后向服务器/书架发送请求，成功才更新图标；失败仅提示，不改变状态。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/dimen.dart';
import '../../../core/utils/format.dart';
import '../../../data/models/album.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/login_sheet.dart';
import '../../bookshelf/bookshelf_providers.dart';

enum _Action { like, favorite, bookshelf }

class DetailActionBar extends ConsumerStatefulWidget {
  const DetailActionBar({super.key, required this.info});

  final AlbumDetail info;

  @override
  ConsumerState<DetailActionBar> createState() => _DetailActionBarState();
}

class _DetailActionBarState extends ConsumerState<DetailActionBar> {
  final _busy = <_Action>{};

  /// 点赞成功后的本地标记（服务端 liked 为 true 时不需要它）。
  bool _likedLocally = false;

  /// 收藏成功后的本地覆盖；null 跟随服务端 [AlbumDetail.isFavorite]。
  bool? _favoriteLocally;

  /// 书架成功后的本地覆盖；null 跟随 [bookshelfProvider] 的成员判定。
  bool? _bookshelfLocally;

  AlbumDetail get info => widget.info;

  Future<void> _run(_Action action, Future<void> Function() act) async {
    if (_busy.contains(action)) return;
    setState(() => _busy.add(action));
    try {
      await act();
    } finally {
      if (mounted) setState(() => _busy.remove(action));
    }
  }

  Future<void> _like() async {
    if (!await ensureLoggedIn(context, ref)) return;
    try {
      final result = await ref.read(apiRepositoryProvider).likeAlbum(info.id);
      if (result.status != 'success') {
        if (mounted) _showMessage('点赞失败：${result.msg}');
        return;
      }
      if (mounted) setState(() => _likedLocally = true);
    } catch (e) {
      if (mounted) _showError(context, e, action: '点赞');
    }
  }

  Future<void> _toggleFavorite() async {
    if (!await ensureLoggedIn(context, ref)) return;
    try {
      final result = await ref.read(apiRepositoryProvider).toggleFavorite(info.id);
      // ok + add 为添加成功；ok + remove 为删除成功；其余视为失败。
      final added = result.status == 'ok' && result.type == 'add';
      final removed = result.status == 'ok' && result.type == 'remove';
      if (!added && !removed) {
        if (mounted) _showMessage('收藏失败：${result.msg}');
        return;
      }
      if (mounted) setState(() => _favoriteLocally = added);
    } catch (e) {
      if (mounted) _showError(context, e, action: '收藏');
    }
  }

  Future<void> _toggleBookshelf() async {
    final next = !ref.read(bookshelfProvider.notifier).contains(info.id);
    try {
      if (next) {
        await ref
            .read(bookshelfProvider.notifier)
            .add(AlbumBrief(id: info.id, name: info.name, author: info.author.join(' ')));
      } else {
        await ref.read(bookshelfProvider.notifier).removeMany([info.id]);
      }
      if (mounted) setState(() => _bookshelfLocally = next);
    } catch (e) {
      if (mounted) {
        _showError(context, e, action: next ? '加入书架' : '移出书架');
      }
    }
  }

  void _showError(BuildContext context, Object error, {required String action}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$action失败：$error')));
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    // watch 书架列表：任何地方的增删都会驱动此处成员判定刷新。
    final contains = ref
        .watch(bookshelfProvider)
        .maybeWhen(data: (books) => books.any((e) => e.id == info.id), orElse: () => false);

    final liked = info.liked || _likedLocally;
    final favorite = _favoriteLocally ?? info.isFavorite;
    final bookshelf = _bookshelfLocally ?? contains;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          _ActionButton(icon: Icons.visibility_outlined, label: compactCount(info.totalViews)),
          _ActionButton(
            icon: liked ? Icons.favorite : Icons.favorite_outline,
            label: compactCount(info.likes),
            selected: liked,
            disabled: liked,
            busy: _busy.contains(_Action.like),
            onTap: () => _run(_Action.like, _like),
          ),
          _ActionButton(
            icon: favorite ? Icons.star : Icons.star_outline,
            label: favorite ? '已收藏' : '收藏',
            selected: favorite,
            busy: _busy.contains(_Action.favorite),
            onTap: () => _run(_Action.favorite, _toggleFavorite),
          ),
          _ActionButton(
            icon: bookshelf ? Icons.collections_bookmark : Icons.add_to_photos_outlined,
            label: bookshelf ? '已在书架' : '加入书架',
            selected: bookshelf,
            disabled: _busy.contains(_Action.bookshelf),
            onTap: () => _run(_Action.bookshelf, _toggleBookshelf),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.selected = false,
    this.disabled = false,
    this.busy = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool disabled;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = !selected && disabled
        ? scheme.outline
        : selected
        ? scheme.primary
        : scheme.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: disabled || busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Dimen.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: busy
                    ? Padding(
                        padding: const EdgeInsets.all(2),
                        child: CircularProgressIndicator(strokeWidth: 2, color: color),
                      )
                    : Icon(icon, size: 22, color: color),
              ),
              const SizedBox(height: Dimen.xs),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
