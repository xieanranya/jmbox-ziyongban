/// 全局设计 token：间距 / 圆角 / 网格与卡片规格。
///
/// 位于 core 层，供 shared/widgets 与 app 层共用。
abstract final class Dimen {
  // ---- 间距 ----
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;

  // ---- 圆角 ----
  static const double rSm = 8;
  static const double rMd = 12;

  // ---- 封面卡片 ----

  /// 封面宽高比（w/h），全 App 统一 3:4。
  static const double coverAspectRatio = 3 / 4;

  /// 首页横滑行的卡片宽度。
  static const double rowCardWidth = 124;

  /// 首页横滑行总高（封面高 + 文案区）。
  static const double rowHeight = 248;

  // ---- 响应式网格 ----

  /// 网格单元格最小宽度（按屏宽取整定列数）。108 可让主流手机（逻辑宽 ~360-430）排下 3 列。
  static const double gridMinExtent = 108;
  static const double gridSpacing = md;
  static const int gridMinColumns = 2;
  static const int gridMaxColumns = 6;

  // ---- 悬浮按钮避让 ----

  /// 列表底部为 FAB 预留的高度：extended FAB 56 + 屏边距 16 + 余量 16。
  static const double fabBottomInset = 88;
}
