/// 专辑详情页：固定 header + 三 Tab（介绍/目录/评论）+ 随 Tab 切换的 FAB。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_routes.dart';
import '../../shared/widgets/async_view.dart';
import '../../data/models/album.dart';
import '../history/history_providers.dart';
import 'album_detail_providers.dart';
import 'widgets/comment_input_sheet.dart';
import 'widgets/detail_action_bar.dart';
import 'widgets/detail_comments_tab.dart';
import 'widgets/detail_header.dart';
import 'widgets/detail_tabs.dart';

class AlbumDetailPage extends ConsumerStatefulWidget {
  const AlbumDetailPage({super.key, required this.id});

  /// 路由参数中的专辑 id；null 说明深链非法。
  final int? id;

  @override
  ConsumerState<AlbumDetailPage> createState() => _AlbumDetailPageState();
}

class _AlbumDetailPageState extends ConsumerState<AlbumDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.id == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyView(message: '无效的专辑链接', icon: Icons.link_off),
      );
    }

    final detail = ref.watch(albumDetailProvider(widget.id!));
    // 章节进度：有记录则 FAB 文案为「继续阅读」，点击直达该章。
    final progress = ref.watch(albumReadingProgressProvider(widget.id!)).value;

    return Scaffold(
      appBar: AppBar(
        // 标题放在返回键右侧；数据未就绪时留空。
        title: switch (detail) {
          AsyncData(:final value) => Text(value.name),
          _ => null,
        },
      ),
      floatingActionButton: switch (detail) {
        AsyncData(:final value) => ListenableBuilder(
          listenable: _tabController,
          builder: (context, _) => _buildFab(value, progress),
        ),
        _ => null,
      },
      body: switch (detail) {
        AsyncData(:final value) => _buildBody(value),
        AsyncError(:final error) => ErrorRetryView(
          error: error,
          onRetry: () => ref.invalidate(albumDetailProvider(widget.id!)),
        ),
        _ => const LoadingView(),
      },
    );
  }

  Widget _buildBody(AlbumDetail info) {
    return Column(
      children: [
        DetailHeader(info: info),
        DetailActionBar(info: info),
        const Divider(height: 1),
        TabBar(
          controller: _tabController,
          tabs: [
            const Tab(text: '介绍'),
            Tab(text: '目录 ${info.series.length}话'),
            Tab(text: '评论 ${info.commentTotal}条'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              IntroTab(info: info),
              TocTab(info: info),
              CommentsTab(
                albumId: info.id,
                onReply: (comment) => showCommentInput(
                  context,
                  albumId: info.id,
                  replyTo: comment.username,
                  replyCid: comment.cid,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 评论页展示「发表」，其余页展示「开始观看」（有进度则为「继续阅读」）。
  Widget _buildFab(AlbumDetail info, int? progress) {
    if (_tabController.index == 2) {
      return FloatingActionButton.extended(
        onPressed: () => showCommentInput(context, albumId: info.id),
        icon: const Icon(Icons.edit),
        label: const Text('发表评论'),
      );
    }
    // 进度章不在本专辑 series 视为无效，置空回退第一话。
    final resume = info.series.any((c) => c.id == progress) ? progress : null;
    return FloatingActionButton.extended(
      onPressed: () => _startReading(info, resume),
      icon: const Icon(Icons.play_arrow),
      label: Text(resume == null ? '开始观看' : '继续阅读'),
    );
  }

  Future<void> _startReading(AlbumDetail info, int? resume) async {
    if (info.series.isEmpty) return;
    await recordAlbumView(ref, AlbumBrief.fromDetail(info));
    if (!mounted) return;
    await context.push('${AppRoutes.reader}/${info.id}/${resume ?? info.series.first.id}');
    // 阅读器内换章会写进度，返回后刷新以更新「继续阅读」文案与落点。
    ref.invalidate(albumReadingProgressProvider(info.id));
  }
}
