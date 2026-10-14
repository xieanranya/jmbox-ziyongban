/// 主机/域名工具：URL 规范化、协议前缀剥离。
///
/// 零 UI 依赖的纯 Dart，供 core/network 与 features 层共用。
library;

/// 规范化域名：补 https://、去路径与 query、末尾补 /。
/// 非法输入返回 null。
String? normalizedBaseUrlOrNull(String raw) {
  var text = raw.trim();
  if (text.isEmpty) return null;
  if (!text.contains('://')) text = 'https://$text';
  final uri = Uri.tryParse(text);
  if (uri == null || uri.host.isEmpty) return null;
  // 校验 host 只含合法域名字符（字母/数字/点/连字符）。
  if (!RegExp(r'^[a-zA-Z0-9.\-]+$').hasMatch(uri.host)) return null;
  // 末尾不带 /：path 常量统一以 / 开头，拼接时不会出现双斜杠（与 Rust 域名格式一致）。
  return '${uri.scheme}://${uri.host}';
}

/// 去掉协议前缀（http/https），仅留域名部分；先 trim 再匹配，空输入返回空串。
String stripScheme(String host) => host.trim().replaceFirst(RegExp('^https?://'), '');
