/// 展示格式规范：字节 / 计数缩写 / 日期。
///
/// 零业务依赖的纯 Dart。收口在此是为统一展示口径（「万」缩写、小数位、日期格式），
/// 避免各页面各写一套；当前每个函数各只有一处调用，属规范集中而非高频复用。
library;

/// 字节数格式化：B / KB / MB / GB。
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}

/// 计数缩写：12345 → 1.2万；10000 → 1万。
String compactCount(int n) {
  if (n < 10000) return '$n';
  final v = (n / 10000).toStringAsFixed(1);
  return '${v.endsWith('.0') ? v.substring(0, v.length - 2) : v}万';
}

/// unix 秒时间戳 → yyyy-MM-dd；非时间戳文本原样展示。
String formatDate(String addtime) {
  final seconds = int.tryParse(addtime);
  if (seconds == null) return addtime;
  final date = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  final mm = date.month.toString().padLeft(2, '0');
  final dd = date.day.toString().padLeft(2, '0');
  return '${date.year}-$mm-$dd';
}
