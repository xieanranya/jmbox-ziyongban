/// 阅读器状态栏：覆盖在阅读画面之上的统一控制层。
///
/// [ReaderStatusBar] 组装顶栏、底栏（带显隐滑动动画）与章节目录弹层，直接读 [ReaderController] 状态。
/// Slider 为「受控草稿」模式：拖拽期间只显示 sliderDraft，松手经 onSliderEnd 才真正跳页。
library;

import 'package:flutter/material.dart';

import '../../../core/constants/dimen.dart';
import '../../../data/models/album.dart';
import '../reader_controller.dart';

/// 阅读器统一状态栏：顶栏 + 底栏 + 目录弹层，随 [ReaderController.controlsVisible] 显隐。
///
/// 透明 [Stack] 覆盖层（宿主以 Positioned.fill 放置），中间空白不拦截手势，点击可穿透到画面。
class ReaderStatusBar extends StatelessWidget {
  const ReaderStatusBar({super.key, required this.controller});

  final ReaderController controller;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _ReaderControlsToggle(
            visible: controller.controlsVisible,
            slideFromTop: true,
            child: _ReaderTopBar(controller: controller),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _ReaderControlsToggle(
            visible: controller.controlsVisible,
            slideFromTop: false,
            child: _ReaderBottomBar(controller: controller),
          ),
        ),
      ],
    );
  }
}

/// 控制栏显隐包装：淡入淡出 + 从顶/底滑入滑出，隐藏后不占命中区。
class _ReaderControlsToggle extends StatelessWidget {
  const _ReaderControlsToggle({
    required this.visible,
    required this.slideFromTop,
    required this.child,
  });

  final bool visible;

  /// true 从顶部滑入（顶栏），false 从底部滑入（底栏）。
  final bool slideFromTop;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        final direction = slideFromTop ? -1.0 : 1.0;
        final slide = Tween<Offset>(
          begin: Offset(0, direction),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: visible
          ? KeyedSubtree(key: const ValueKey('on'), child: child)
          : const SizedBox(key: ValueKey('off')),
    );
  }
}

/// 顶部栏：返回 + 「第 X / N 话」+ 章节名。
class _ReaderTopBar extends StatelessWidget {
  const _ReaderTopBar({required this.controller});

  final ReaderController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      // 半透明 surface：与页面/AppBar 同源，随主题明暗；留一点透明度透出画面。
      color: scheme.surface.withValues(alpha: 0.92),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '第 ${controller.chapterIndex + 1} / ${controller.chapters.length} 话',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    controller.chapter.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: Dimen.xl),
          ],
        ),
      ),
    );
  }
}

/// 底部栏：页码 + 百分比 + 进度条 + 上一章 / 目录 / 下一章。
class _ReaderBottomBar extends StatelessWidget {
  const _ReaderBottomBar({required this.controller});

  final ReaderController controller;

  Future<void> _openCatalog(BuildContext context) async {
    // 章节列表以控制器为唯一来源（初始章就绪后填充）。
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) =>
          _ReaderCatalogSheet(chapters: controller.chapters, currentIndex: controller.chapterIndex),
    );
    if (selected != null) controller.selectChapter(selected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pageIndex = controller.currentPage;
    final sliderValue = controller.sliderDraft;
    final pageCount = controller.pageCount;
    final safeTotal = pageCount < 1 ? 1 : pageCount;
    final sliderEnd = (safeTotal - 1).toDouble();
    final displayPage = ((sliderValue ?? pageIndex).round().clamp(0, safeTotal - 1)) + 1;
    final percent = (displayPage * 100 / safeTotal).floor();

    return Material(
      // 半透明 surface：与页面/AppBar 同源，随主题明暗；留一点透明度透出画面。
      color: scheme.surface.withValues(alpha: 0.92),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Dimen.lg, Dimen.md, Dimen.lg, Dimen.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$displayPage / $pageCount',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500),
                  ),
                  Text('$percent%', style: theme.textTheme.bodySmall),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                ),
                child: Slider(
                  value: (sliderValue ?? pageIndex).toDouble().clamp(0.0, sliderEnd),
                  min: 0,
                  max: sliderEnd,
                  activeColor: scheme.primary,
                  inactiveColor: scheme.onSurface.withValues(alpha: 0.24),
                  onChanged: pageCount > 1 ? controller.onSliderChanged : null,
                  onChangeEnd: pageCount > 1 ? (_) => controller.onSliderEnd() : null,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _BarButton(
                    icon: Icons.chevron_left,
                    label: '上一章',
                    enabled: controller.chapterIndex > 0,
                    onTap: controller.selectPreviousChapter,
                  ),
                  _BarButton(
                    icon: Icons.list_alt,
                    label: '目录',
                    enabled: true,
                    onTap: () => _openCatalog(context),
                  ),
                  _BarButton(
                    icon: Icons.chevron_right,
                    label: '下一章',
                    enabled: controller.chapterIndex < controller.chapters.length - 1,
                    onTap: controller.selectNextChapter,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 底栏图标按钮：仅图标，禁用态降透明度，label 作 tooltip 补足可读性。
class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface.withValues(alpha: enabled ? 1.0 : 0.38);
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(Dimen.rSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Dimen.xl, vertical: Dimen.xs),
          child: Icon(icon, color: color, size: 28),
        ),
      ),
    );
  }
}

/// 章节目录弹层：列出全部章节，点选切章并高亮当前。
class _ReaderCatalogSheet extends StatelessWidget {
  const _ReaderCatalogSheet({required this.chapters, required this.currentIndex});

  final List<Series> chapters;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(Dimen.lg),
            child: Text('选择章节', style: Theme.of(context).textTheme.titleMedium),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: chapters.length,
              itemBuilder: (context, index) {
                final chapter = chapters[index];
                final selected = index == currentIndex;
                return ListTile(
                  selected: selected,
                  selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
                  title: Text(
                    chapter.name.isEmpty ? '第${index + 1}话' : chapter.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: selected
                      ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () => Navigator.of(context).pop(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
