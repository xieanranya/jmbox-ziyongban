/// 阅读器调参常量：预取窗口、预热距离、页面几何基准等经验值。
///
/// 与逻辑分离，集中在此便于观察与调整。
library;

/// 跳页后重新落位的确认次数：目标页首帧可能量不到真实高度，兜底再滚一次。
/// 刻意很小——章末余量不足时本就该被夹住，不该无限纠正。
const int kReaderJumpSettleAttempts = 2;

/// 图片预取窗口：向阅读主方向（向下即页码增大）取 [kReaderPrefetchAhead] 页、
/// 反向留 [kReaderPrefetchBehind] 页（磁盘级下载，不预解码）。
/// 不区分实际滚动方向：向上回翻是小概率事件，固定多留去程、少留来路即可。
const int kReaderPrefetchAhead = 5;
const int kReaderPrefetchBehind = 2;

// ---- 页面几何 ----

/// 整章都还没测出尺寸时的兜底高宽比（高/宽）：约等于 JM 页按视口宽铺满的实际比例。
const double kDefaultPageAspect = 1.42;

/// 比例上下限：防畸形图（一张 1×20000 的图不该撑出几万高的 item）。
const double kMinPageAspect = 0.05;
const double kMaxPageAspect = 20.0;

/// 估算中位数时最多参考多少个已测页。JM 同章各页尺寸高度一致，取样再多也不会更准。
const int kGeometrySampleLimit = 16;

// ---- 点击热区 ----

/// 中央点击热区相对视口的宽/高占比：仅屏幕中间这块区域响应点击切控制栏，
/// 避开顶/底易误触带（滚动时拇指常落在边缘）。各取 0.5 即中间 1/4 面积。
/// 判定在 [_ReaderViewState._onTapUp] 里按点击坐标完成，非独立热区层（后者会吞掉滚动）。
const double kReaderTapZoneWidthFactor = 0.5;
const double kReaderTapZoneHeightFactor = 0.5;
