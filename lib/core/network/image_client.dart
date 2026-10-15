/// JM 图片客户端：封面 / 章节图下载（返回原始字节，解密还原由上层负责）。
library;

import 'dart:developer';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../constants/app_constants.dart';
import 'exception.dart';

/// 图片端点路径。
abstract final class ImageEndpoints {
  static const mediaAlbums = '/media/albums';
  static const mediaPhotos = '/media/photos';
}

class ImageClient {
  /// [hosts] 提供候选图片主机列表（当前选定主机在前，其余为候补）。
  /// 本地定制：单台失败自动切换下一台候选，全部失败才抛错，
  /// 避免服务端推荐的域名在部分网络下不通导致图片全挂。
  ImageClient({required List<String> Function() hosts})
    : _hosts = hosts,
      _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          headers: {'User-Agent': kUserAgent},
        ),
      );

  final List<String> Function() _hosts;

  final Dio _dio;

  /// 封面图字节（`imageName` 可为 `{albumId}.jpg` 或 `{albumId}_3x4.jpg`）。
  Future<Uint8List> getCover(String imageName) =>
      _requestImage('${ImageEndpoints.mediaAlbums}/$imageName');

  /// 章节图原始字节（分块重排由上层负责）。
  Future<Uint8List> getPhoto(int chapterId, String imageName) =>
      _requestImage('${ImageEndpoints.mediaPhotos}/$chapterId/$imageName');

  /// 下载一张图。依次尝试候选主机列表：当前主机先按 [kMaxAttempts] 同机重试
  /// （覆盖瞬时故障），彻底失败后切换下一台候选主机，直到成功或全部用尽。
  Future<Uint8List> _requestImage(String path) async {
    final candidates = _hosts();
    if (candidates.isEmpty) {
      throw const ApiException('没有可用图片域名');
    }
    ApiException? lastError;
    for (final host in candidates) {
      for (var attempt = 0; attempt < kMaxAttempts; attempt++) {
        try {
          return await _requestOnce(host, path);
        } on ApiException catch (e) {
          lastError = e;
          if (!e.retryableOnSameHost) break; // 非瞬时故障：换下一台主机
        }
      }
    }
    // 全部候选主机用尽：抛最后一次的真实错误，上层才看得到确切原因。
    throw lastError!;
  }

  Future<Uint8List> _requestOnce(String host, String path) async {
    final url = '$host$path';
    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        // 部分 CDN 内部出错时回 200 + 0 字节，HTTP 层完全看不出异常，落盘就是一张
        // 0 字节的"成功"图片。按网络错误上报，同机重试一次。
        throw const ApiException('图片数据为空', isNetworkError: true);
      }
      return Uint8List.fromList(bytes);
    } on DioException catch (e) {
      // 无 response 说明压根没拿到 HTTP 响应（连接失败/超时）；有 response 则是服务端明确回了状态码。
      final statusCode = e.response?.statusCode;
      log('图片下载失败 url=$url status=$statusCode: $e', name: 'ImageClient');
      throw ApiException('图片下载失败', statusCode: statusCode, isNetworkError: statusCode == null);
    }
  }
}
