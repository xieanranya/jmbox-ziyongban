/// 筛选栏：横向滚动 chips 行 + 下拉 chip。
///
/// 使用方：RemoteGridPage 的 filterBar 插槽（各列表页）。
library;

import 'package:flutter/material.dart';

import '../../core/constants/dimen.dart';

/// 筛选栏行。
class FilterBar extends StatelessWidget {
  const FilterBar({super.key, required this.children});

  /// 通常为若干 [FilterDropdown]。
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Dimen.lg),
        children: children,
      ),
    );
  }
}

/// 筛选下拉 chip。基于 [MenuAnchor]（Material 3）：菜单出现在 chip 下方、
/// 宽度与 chip 一致、最多显示 5 条（超出滚动）。
class FilterDropdown<T> extends StatefulWidget {
  const FilterDropdown({
    super.key,
    required this.value,
    required this.entries,
    required this.onChanged,
    this.prefix,
  });

  final T value;
  final List<MapEntry<T, String>> entries;
  final ValueChanged<T> onChanged;
  final String? prefix;

  @override
  State<FilterDropdown<T>> createState() => _FilterDropdownState<T>();
}

class _FilterDropdownState<T> extends State<FilterDropdown<T>> {
  /// 用于测量 chip 宽度，使菜单宽度与 chip 一致。
  final GlobalKey _chipKey = GlobalKey();

  /// 菜单最多显示 5 条，超出部分滚动。
  static const int _maxVisibleItems = 5;

  /// [MenuStyle] 的属性在菜单打开时才调用 [WidgetStateProperty.resolve]，
  /// 此时 chip 已完成布局，宽度准确。
  double get _chipWidth =>
      (_chipKey.currentContext?.findRenderObject() as RenderBox?)?.size.width ?? 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = widget.value;
    final entries = widget.entries;
    final currentLabel = entries.isEmpty
        ? ''
        : entries.firstWhere((e) => e.key == value, orElse: () => entries.first).value;

    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.prefix != null) ...[
          Text(
            widget.prefix!,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 4),
        ],
        Text(currentLabel, style: theme.textTheme.bodyMedium),
        const Icon(Icons.arrow_drop_down, size: 18),
      ],
    );

    return MenuAnchor(
      // 关闭后宽度约束才生效，菜单得以与 chip 等宽（默认 true 会取内容固有宽度绕过约束）。
      crossAxisUnconstrained: false,
      style: MenuStyle(
        // 用 minimum/maximumSize 夹出与 chip 等宽；不能用 fixedSize（高度无穷会被 maxHeight 收敛、撑出留白）。
        minimumSize: WidgetStateProperty.resolveWith((states) => Size(_chipWidth, 0)),
        maximumSize: WidgetStateProperty.resolveWith(
          (states) => Size(_chipWidth, _maxVisibleItems * kMinInteractiveDimension),
        ),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 4)),
      ),
      menuChildren: [
        for (final entry in entries)
          MenuItemButton(
            onPressed: () {
              // 选中当前值不触发回调，避免无意义刷新。
              if (entry.key == value) return;
              widget.onChanged(entry.key);
            },
            child: Text(entry.value),
          ),
      ],
      builder: (context, controller, child) => Padding(
        padding: const EdgeInsets.only(right: 8),
        // Material 在外承载底色、InkWell 在其内，墨迹才能盖在底色上（InkWell 包 Material 会被底色挡住）。
        child: Material(
          key: _chipKey,
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            hoverColor: theme.colorScheme.primary.withValues(alpha: 0.12),
            splashColor: theme.colorScheme.primary.withValues(alpha: 0.2),
            onTap: () => controller.isOpen ? controller.close() : controller.open(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: label,
            ),
          ),
        ),
      ),
    );
  }
}
