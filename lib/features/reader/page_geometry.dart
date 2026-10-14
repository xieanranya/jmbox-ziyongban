/// 阅读器页面几何状态：一话各页高宽比的「随读随测」缓存。
///
/// 未加载页占位高≠真实高会让跳页落点乱跳，故给每页一个尽量接近真实的估算高：
/// 本页实测值 > 本章中位数（JM 同章各页尺寸一致）> 默认比例。仅会话级内存缓存，退出即释放。
/// 纯数学为本文件末尾的库私有顶层函数，基准常量见 core/constants/reader_config.dart。
library;

import '../../core/constants/reader_config.dart';

/// 一话里各页的高宽比，随读随测。
/// 已测值按页码存于 [_permille]，量到新页就地更新；中位数缓存在 [_estimate]，
/// 不在 [aspectOf] 里重算（那是每页每帧的热路径）。
class PageGeometry {
  /// 从「整章未测」起步：[_permille] 随 record 按需增长，[_estimate] 待首帧实测后收敛。
  PageGeometry() : _estimate = 0;

  final List<int> _permille = [];

  /// 最近参与估算的页面下标；同一页只保留一次，重新测量后移到队尾。
  final List<int> _samplePages = [];
  int _estimate;

  /// 第 [index] 页的占位比例。
  double aspectOf(int index) => _pageAspect(
    measuredPermille: index >= 0 && index < _permille.length ? _permille[index] : 0,
    estimatePermille: _estimate,
  );

  /// 记录第 [index] 页实测尺寸，更新中位数估算。
  void record(int index, int width, int height) {
    if (index < 0) return;
    final value = _heightPermille(width, height);
    if (value <= 0) return;
    while (_permille.length <= index) {
      _permille.add(0);
    }
    if (_permille[index] == value) return;
    _permille[index] = value;

    // 页面重新布局可能得到新尺寸：移除旧位置，避免同一页在中位数中重复计权。
    _samplePages.remove(index);
    if (_samplePages.length >= kGeometrySampleLimit) {
      _samplePages.removeAt(0);
    }
    _samplePages.add(index);
    _estimate = _medianPermille(_samplePages.map((page) => _permille[page]));
  }
}

// ---- 页面几何纯计算（无状态、无 IO；库私有，仅供本文件 PageGeometry 调用） ----

/// 高宽比转成千分数存：一页只占四五个字符，一话四百页也就两千字节。
/// 非法输入返回 0（表示「未测」）。
int _heightPermille(int width, int height) {
  if (width <= 0 || height <= 0) return 0;
  return (height * 1000 ~/ width).clamp(0, 1 << 31);
}

/// 已测页高宽比（千分数）的中位数。取中位数而非均值：偶尔一页跨页大图不该把整章估算带偏。
/// 空集合返回 0。
int _medianPermille(Iterable<int> values) {
  final measured = values.where((v) => v > 0).toList()..sort();
  if (measured.isEmpty) return 0;
  return measured[measured.length ~/ 2];
}

/// 这一页占位用多高（高/宽）。优先本页实测值，其次本章估算值，都没有才用 [fallback]。
double _pageAspect({
  required int measuredPermille,
  required int estimatePermille,
  double fallback = kDefaultPageAspect,
}) {
  final chosen = measuredPermille > 0 ? measuredPermille : estimatePermille;
  if (chosen <= 0) return fallback;
  return (chosen / 1000.0).clamp(kMinPageAspect, kMaxPageAspect);
}
