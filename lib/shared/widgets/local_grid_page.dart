/// 多选卡片网格页：长按多选 + 批量移除 + 返回拦截 + 下拉刷新。
///
/// 依赖：AlbumCard、grid_utils、async_view。
/// 使用方：书架页、观看历史页。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/album.dart';
import '../../core/constants/dimen.dart';
import 'album_card.dart';
import 'async_view.dart';
import 'grid_utils.dart';

class LocalGridPage extends ConsumerStatefulWidget {
  const LocalGridPage({
    super.key,
    required this.title,
    required this.items,
    required this.onRemoveMany,
    required this.onRetry,
    required this.emptyMessage,
    this.emptyIcon = Icons.inbox_outlined,
    this.heroTagPrefix = 'local',
    this.removedLabel = '已删除',
    this.removedUnit = '条记录',
  });

  /// AppBar 标题（多选态显示「已选 N 项」）。
  final String title;

  /// 列表数据（调用方 Provider 的 AsyncValue）。
  final AsyncValue<List<AlbumBrief>> items;

  /// 批量移除回调（调用方 Notifier 的 removeMany）。
  final Future<void> Function(List<int> albumIds) onRemoveMany;

  /// 加载失败重试（如 ref.invalidate(provider)）。
  final VoidCallback onRetry;

  /// 空态文案与图标。
  final String emptyMessage;
  final IconData emptyIcon;

  /// Hero 标签前缀（避免转场冲突）。
  final String heroTagPrefix;

  /// 移除成功反馈：'$removedLabel $count $removedUnit'。
  final String removedLabel;
  final String removedUnit;

  @override
  ConsumerState<LocalGridPage> createState() => _LocalGridPageState();
}

class _LocalGridPageState extends ConsumerState<LocalGridPage> {
  final _selected = <int>{};
  bool _selecting = false;

  void _toggle(AlbumBrief album) {
    setState(() {
      _selecting = true;
      // Set.remove 成功=取消选中，失败=新增选中。
      if (!_selected.remove(album.id)) _selected.add(album.id);
    });
  }

  void _exitSelecting() => setState(() {
    _selecting = false;
    _selected.clear();
  });

  Future<void> _removeSelected() async {
    final count = _selected.length;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.onRemoveMany(_selected.toList());
      messenger.showSnackBar(
        SnackBar(content: Text('${widget.removedLabel} $count ${widget.removedUnit}')),
      );
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('删除失败，请重试')));
    }
    if (mounted) _exitSelecting();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;

    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selecting) _exitSelecting();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _selecting
              ? IconButton(icon: const Icon(Icons.close), onPressed: _exitSelecting)
              : null,
          title: Text(_selecting ? '已选 ${_selected.length} 项' : widget.title),
          actions: [
            if (_selecting) ...[
              IconButton(
                tooltip: '全选',
                icon: const Icon(Icons.select_all),
                onPressed: () => setState(() {
                  _selected
                    ..clear()
                    ..addAll((items.value ?? []).map((a) => a.id));
                }),
              ),
              IconButton(
                tooltip: widget.removedLabel,
                icon: const Icon(Icons.delete_outline),
                onPressed: _removeSelected,
              ),
            ],
          ],
        ),
        body: items.when(
          loading: () => const LoadingView(),
          error: (error, _) => ErrorRetryView(error: error, onRetry: widget.onRetry),
          data: (list) => RefreshIndicator.adaptive(
            onRefresh: () async => widget.onRetry(),
            child: list.isEmpty
                ? ScrollableStatusView(
                    child: EmptyView(message: widget.emptyMessage, icon: widget.emptyIcon),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) => GridView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(Dimen.lg),
                      gridDelegate: albumGridDelegate(constraints.maxWidth - Dimen.lg * 2),
                      itemCount: list.length,
                      itemBuilder: (context, index) => _item(context, list[index]),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _item(BuildContext context, AlbumBrief album) {
    final isSelected = _selected.contains(album.id);
    return GestureDetector(
      onLongPress: () => _toggle(album),
      child: Stack(
        children: [
          AlbumCard(
            album: album,
            heroTag: '${widget.heroTagPrefix}-${album.id}',
            onTap: _selecting ? () => _toggle(album) : null,
          ),
          if (_selecting)
            Positioned(
              top: Dimen.sm,
              right: Dimen.sm,
              child: Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isSelected ? Theme.of(context).colorScheme.primary : null,
              ),
            ),
        ],
      ),
    );
  }
}
