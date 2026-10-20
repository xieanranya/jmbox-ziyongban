/// 评论输入面板：发表 / 回复指定评论。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/dimen.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/login_sheet.dart';
import '../album_detail_providers.dart';

/// 弹出评论输入面板；[replyTo] / [replyCid] 非空时为回复指定评论。
Future<void> showCommentInput(
  BuildContext context, {
  required int albumId,
  String? replyTo,
  int? replyCid,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _CommentInputSheet(albumId: albumId, replyTo: replyTo, replyCid: replyCid),
  );
}

class _CommentInputSheet extends ConsumerStatefulWidget {
  const _CommentInputSheet({required this.albumId, this.replyTo, this.replyCid});

  final int albumId;
  final String? replyTo;
  final int? replyCid;

  @override
  ConsumerState<_CommentInputSheet> createState() => _CommentInputSheetState();
}

class _CommentInputSheetState extends ConsumerState<_CommentInputSheet> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final content = _controller.text.trim();
    if (content.isEmpty) return;

    // 未登录先引导登录；登录成功继续本次输入。
    if (!await ensureLoggedIn(context, ref) || !mounted) return;

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref
          .read(apiRepositoryProvider)
          .postComment(widget.albumId, content, commentId: widget.replyCid);
      if (result.status != 'ok') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.msg)));
          setState(() => _busy = false);
        }
        return;
      }
      ref.invalidate(commentsControllerProvider(widget.albumId));
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(result.msg)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('发送失败：$e')));
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Dimen.lg,
          Dimen.lg,
          Dimen.lg,
          Dimen.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          spacing: Dimen.sm,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !_busy,
                autofocus: true,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: widget.replyTo == null ? '发表评论…' : '回复 ${widget.replyTo}…',
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            IconButton.filled(
              tooltip: '发送',
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              onPressed: _busy ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
