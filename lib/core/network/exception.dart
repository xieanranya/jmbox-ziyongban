/// 网络层异常。
///
/// API 主机运行期冻结（选路只在 bootstrap 与设置页切换时发生）：不做换机重试，
/// 重试判定只看 [retryableOnSameHost]。
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.apiCode, this.isNetworkError = false});

  final String message;

  /// HTTP 状态码；网络层错误（压根没拿到响应）时为 null。
  final int? statusCode;

  /// JM 业务 envelope 的 code（HTTP 200 包裹的响应码），无则为 null。
  final int? apiCode;

  /// true = 连接失败/超时等网络层错误。
  final bool isNetworkError;

  /// 同一台主机重试有机会的瞬时故障：网络层错误、408/429/5xx。
  /// 403（地区封锁）同机救不回；业务码/解析失败必然复现，都不重试。
  bool get retryableOnSameHost =>
      isNetworkError ||
      statusCode == 408 ||
      statusCode == 429 ||
      (statusCode != null && statusCode! >= 500);

  @override
  String toString() =>
      'ApiException: $message (statusCode: $statusCode, apiCode: $apiCode, isNetworkError: $isNetworkError)';
}
