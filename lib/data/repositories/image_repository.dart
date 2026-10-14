/// 图片仓库：下载 + 磁盘缓存（统一返回缓存文件，解码由 UI 侧负责）。
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:pool/pool.dart';

import '../../core/network/image_client.dart';
import '../../core/storage/app_paths.dart';

class ImageRepository {
  ImageRepository(String? Function() imageHost, {int concurrency = 10})
    : _imageClient = ImageClient(host: imageHost),
      _pool = Pool(concurrency);

  final ImageClient _imageClient;
  final Pool _pool;

  /// 同一缓存 key 正在执行的下载。线程池限制总并发，本表进一步合并同图请求。
  final Map<String, Future<File>> _inFlight = {};

  Future<File> getCover(String imageName) =>
      _cached('covers/$imageName', () => _imageClient.getCover(imageName));

  Future<File> getPhoto(int chapterId, String imageName) =>
      _cached('photos/$chapterId/$imageName', () => _imageClient.getPhoto(chapterId, imageName));

  Future<File> _cached(String key, Future<Uint8List> Function() fetch) async {
    final file = File('${AppPaths.images.path}/$key');
    if (await file.exists()) return file;

    final pending = _inFlight[key];
    if (pending != null) return pending;

    final download = _pool.withResource(() async {
      // 等待期间可能已被其他请求下载，双重检查
      if (await file.exists()) return file;
      final bytes = await fetch();
      await file.create(recursive: true);
      await file.writeAsBytes(bytes);
      return file;
    });
    _inFlight[key] = download;
    try {
      return await download;
    } finally {
      // 仅清理由本次登记的 Future，避免失败重试的新任务被旧回调误删。
      if (identical(_inFlight[key], download)) _inFlight.remove(key);
    }
  }

  Future<int> totalSize() async {
    final dir = AppPaths.images;
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  Future<void> clearCache() async {
    final dir = AppPaths.images;
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}
