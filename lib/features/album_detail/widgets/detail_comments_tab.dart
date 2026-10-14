/// 评论 Tab：卡片式列表、嵌套回复默认收起、点正文/回复弹回复框。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../../core/constants/dimen.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/grid_utils.dart';
import '../../../data/models/comment.dart';
import '../../../shared/widgets/login_sheet.dart';
import '../album_detail_providers.dart';

class CommentsTab extends ConsumerStatefulWidget {
  const CommentsTab({super.key, required this.albumId, this.onReply});

  final int albumId;

  final void Function(CommentInfo comment)? onReply;

  @override
  ConsumerState<CommentsTab> createState() => _CommentsTabState();
}

class _CommentsTabState extends ConsumerState<CommentsTab> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(commentsControllerProvider(widget.albumId));
    return PagingListener<int, CommentInfo>(
      controller: controller,
      builder: (context, state, fetchNextPage) => PagedListView<int, CommentInfo>.separated(
        state: state,
        fetchNextPage: fetchNextPage,
        scrollController: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(Dimen.lg),
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        builderDelegate: pagedDelegate<CommentInfo>(
          error: state.error,
          onRetry: controller.refresh,
          fetchNextPage: fetchNextPage,
          emptyView: const EmptyView(message: '暂无评论，抢个沙发？', icon: Icons.forum_outlined),
          itemBuilder: (context, comment, index) =>
              _CommentTile(comment: comment, onReply: (target) => _replyTo(context, ref, target)),
        ),
      ),
    );
  }

  /// 未登录先弹登录框，登录成功后继续打开回复框。
  Future<void> _replyTo(BuildContext context, WidgetRef ref, CommentInfo target) async {
    if (!await ensureLoggedIn(context, ref) || !context.mounted) return;
    widget.onReply?.call(target);
  }
}

/// 单条评论卡：点正文回复；嵌套回复默认收起，可展开/收起。
class _CommentTile extends StatefulWidget {
  const _CommentTile({required this.comment, required this.onReply});

  final CommentInfo comment;
  final Future<void> Function(CommentInfo target) onReply;

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  bool _repliesExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final comment = widget.comment;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    comment.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500),
                  ),
                ),
                Text(
                  comment.addtime,
                  style: theme.textTheme.labelSmall?.copyWith(color: scheme.outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () => widget.onReply(comment),
              child: Text(
                comment.content,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ),
            if (comment.replys.isNotEmpty) ...[
              const SizedBox(height: 10),
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () => setState(() => _repliesExpanded = !_repliesExpanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${comment.replys.length} 条回复',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: scheme.primary,
                        ),
                      ),
                      AnimatedRotation(
                        turns: _repliesExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(Icons.expand_more, size: 18, color: scheme.primary),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity),
                secondChild: _buildReplies(comment.replys),
                crossFadeState: _repliesExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
                sizeCurve: Curves.easeOut,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReplies(List<CommentInfo> replies) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final reply in replies) _ReplyTile(reply: reply, onReply: () => widget.onReply(reply)),
      ],
    );
  }
}

/// 单条嵌套回复：左侧竖线导轨，点击可回复。
class _ReplyTile extends StatelessWidget {
  const _ReplyTile({required this.reply, required this.onReply});

  final CommentInfo reply;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(width: 2, color: scheme.primaryContainer)),
      ),
      padding: const EdgeInsets.only(left: 10, top: 6, bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onReply,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    reply.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: scheme.primary,
                    ),
                  ),
                ),
                Text(
                  reply.addtime,
                  style: theme.textTheme.labelSmall?.copyWith(color: scheme.outline),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(reply.content, style: theme.textTheme.bodySmall?.copyWith(height: 1.4)),
          ],
        ),
      ),
    );
  }
}
