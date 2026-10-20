/// 通用分区组件：分区标题 + 水平留白圆角卡片容器。
///
/// 有业务依赖（Theme/Dimen），置于 shared 层，供 category/profile/settings 等复用。
library;

import 'package:flutter/material.dart';

import '../../core/constants/dimen.dart';

/// 分区标题：单行文本 + 留白，超出省略。默认取「强调标签」样式（primary 色 [titleSmall]），
/// 覆盖设置页/个人页的分区标题。其它场景（分类页区块头、弹窗内小标题）通过 [padding]
/// 与 [style] 定制，避免各处重复实现同一模式。
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.padding = const EdgeInsets.fromLTRB(Dimen.lg, Dimen.xl, Dimen.lg, Dimen.sm),
    this.style,
  });

  final String title;

  /// 标题留白；默认水平 [Dimen.lg]、上 [Dimen.xl]、下 [Dimen.sm]。
  final EdgeInsetsGeometry padding;

  /// 文字样式；为空时用 primary 色 [titleSmall]。
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style ?? theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }
}

/// 分区卡片：水平留白的圆角 Card，内部纵向排列子项。
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: Dimen.lg),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}
