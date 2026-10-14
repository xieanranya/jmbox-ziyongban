/// JM API 客户端：Token 头 + AES 解密 + 错误处理 + 各端点封装。
///
/// 所有方法返回解密后的 JSON 字符串，模型解析由 data 层负责。
library;

import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import '../constants/app_constants.dart';
import 'exception.dart';
import '../utils/jm_crypto.dart';

/// API 端点路径。
abstract final class Endpoints {
  static const album = '/album';
  static const chapter = '/chapter';
  static const scrambleId = '/chapter_view_template';
  static const search = '/search';
  static const promote = '/promote';
  static const promoteList = '/promote_list';
  static const serialization = '/serialization';
  static const categories = '/categories';
  static const categoriesFilter = '/categories/filter';
  static const week = '/week';
  static const weekFilter = '/week/filter';
  static const setting = '/setting';
  static const login = '/login';
  static const logout = '/logout';
  static const favorite = '/favorite';
  static const like = '/like';
  static const forum = '/forum';
  static const comment = '/comment';
  static const daily = '/daily';
  static const dailyChk = '/daily_chk';
}

class ApiClient {
  /// [host] 提供当前 API 主机（运行期冻结，选路变化由上层在 bootstrap/设置页完成）。
  ApiClient({required this._host})
    : _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          headers: {'User-Agent': kUserAgent},
        ),
      )..interceptors.add(CookieManager(CookieJar()));

  final String? Function() _host;

  final Dio _dio;

  // ---- 专辑 / 章节 ----

  Future<String> getAlbum(int id) =>
      _requestApi(method: 'GET', path: Endpoints.album, query: {'id': id});

  Future<String> getChapter(int id) =>
      _requestApi(method: 'GET', path: Endpoints.chapter, query: {'id': id});

  /// 获取图片解密所需的 scramble id（返回 HTML，解析 `var scramble_id = ...`）。
  Future<String> getScrambleId(int id) async {
    final baseUrl = _host();
    if (baseUrl == null) {
      throw const ApiException('没有可用 API 域名');
    }
    final time = nowSeconds();
    final response = await _dio.request<String>(
      '$baseUrl${Endpoints.scrambleId}',
      queryParameters: {
        'id': id,
        'v': time,
        'mode': 'vertical',
        'page': 0,
        'app_img_shunt': 1,
        'express': 'off',
      },
      options: Options(
        responseType: ResponseType.plain,
        headers: {'Tokenparam': buildTokenparam(time), 'Token': buildToken(time, true)},
      ),
    );
    return response.data ?? '';
  }

  // ---- 搜索 / 推荐 / 连载 / 分类 / 每周 ----

  Future<String> search(String keyword, int page, String sort) => _requestApi(
    method: 'GET',
    path: Endpoints.search,
    query: {'search_query': keyword, 'page': page, 'o': sort},
  );

  Future<String> getPromote() async {
    final time = nowSeconds();
    return _requestApi(method: 'GET', path: Endpoints.promote, query: {'_': time});
  }

  Future<String> getPromoteList(int id, int page) =>
      _requestApi(method: 'GET', path: Endpoints.promoteList, query: {'id': id, 'page': page});

  Future<String> getSerialization(String date, String type, int page) => _requestApi(
    method: 'GET',
    path: Endpoints.serialization,
    query: {'date': date, 'type': type, 'page': page},
  );

  Future<String> getCategories() => _requestApi(method: 'GET', path: Endpoints.categories);

  Future<String> getCategoriesFilter(String category, int page, String sort) => _requestApi(
    method: 'GET',
    path: Endpoints.categoriesFilter,
    query: {'c': category, 'o': sort, 'page': page},
  );

  Future<String> getWeekInfo() => _requestApi(method: 'GET', path: Endpoints.week);

  Future<String> getWeekFilter(int categoryId, String typeId) => _requestApi(
    method: 'GET',
    path: Endpoints.weekFilter,
    query: {'id': categoryId, 'type': typeId},
  );

  /// 获取应用设置（含服务端下发的图片主机、API 版本、线路列表）。
  /// 带时间戳参数绕过 CDN 缓存，保证拿到最新值。
  Future<String> getSetting() async {
    final time = nowSeconds();
    return _requestApi(method: 'GET', path: Endpoints.setting, query: {'t': time});
  }

  // ---- 用户 / 收藏 / 点赞 / 评论 / 签到 ----

  Future<String> login(String username, String password) => _requestApi(
    method: 'POST',
    path: Endpoints.login,
    form: {'username': username, 'password': password},
  );

  Future<String> logout() => _requestApi(method: 'POST', path: Endpoints.logout);

  Future<String> getFavorite(int folderId, int page, String sort) => _requestApi(
    method: 'GET',
    path: Endpoints.favorite,
    query: {'folder_id': folderId, 'page': page, 'o': sort},
  );

  Future<String> toggleFavorite(int albumId) =>
      _requestApi(method: 'POST', path: Endpoints.favorite, form: {'aid': albumId});

  Future<String> likeAlbum(int albumId) =>
      _requestApi(method: 'POST', path: Endpoints.like, form: {'id': albumId});

  Future<String> getComments(int albumId, int page) => _requestApi(
    method: 'GET',
    path: Endpoints.forum,
    query: {'mode': 'manhua', 'aid': albumId, 'page': page},
  );

  Future<String> postComment(int albumId, String content, {int? commentId}) => _requestApi(
    method: 'POST',
    path: Endpoints.comment,
    form: {'aid': albumId, 'comment': content, 'comment_id': ?commentId},
  );

  Future<String> getDaily(String userId) =>
      _requestApi(method: 'GET', path: Endpoints.daily, query: {'user_id': userId});

  Future<String> checkDaily(String userId, int dailyId) => _requestApi(
    method: 'POST',
    path: Endpoints.dailyChk,
    form: {'user_id': userId, 'daily_id': dailyId},
  );

  // ---- 核心请求 ----

  /// 发一次请求。API 主机运行期冻结（选路只在 bootstrap 与手动切换时发生），
  /// 不做换机重试；仅对同机有机会的瞬时故障（见 [ApiException.retryableOnSameHost]）
  /// 重试，其余错误直接上抛。
  Future<String> _requestApi({
    required String method,
    required String path,
    Map<String, dynamic>? query,
    Map<String, dynamic>? form,
  }) async {
    final baseUrl = _host();
    if (baseUrl == null) {
      throw const ApiException('没有可用 API 域名');
    }
    ApiException? lastError;
    for (var attempt = 0; attempt < kMaxAttempts; attempt++) {
      try {
        return await _requestOnce(baseUrl, method: method, path: path, query: query, form: form);
      } on ApiException catch (e) {
        lastError = e;
        if (!e.retryableOnSameHost) rethrow;
      }
    }
    // 尝试次数用尽：抛最后一次的真实错误，上层才看得到确切原因。
    throw lastError!;
  }

  Future<String> _requestOnce(
    String baseUrl, {
    required String method,
    required String path,
    Map<String, dynamic>? query,
    Map<String, dynamic>? form,
  }) async {
    // Token 头与响应解密共用同一时间戳
    final time = nowSeconds();
    final String body;

    try {
      final response = await _dio.request(
        '$baseUrl$path',
        queryParameters: query,
        data: form == null ? null : FormData.fromMap(form),
        options: Options(
          method: method,
          responseType: ResponseType.plain,
          headers: {'Tokenparam': buildTokenparam(time), 'Token': buildToken(time, false)},
        ),
      );
      body = response.data.toString();
    } on DioException catch (e) {
      // 无 response 说明压根没拿到 HTTP 响应（连接失败/超时）；有 response 则是服务端明确回了状态码。
      final statusCode = e.response?.statusCode;
      throw ApiException(
        _extractErrorMsg(e),
        statusCode: statusCode,
        isNetworkError: statusCode == null,
      );
    }
    return _parseApiResponse(time, body);
  }

  String _extractErrorMsg(DioException e) {
    final data = e.response?.data;
    if (data is String) {
      try {
        final json = jsonDecode(data) as Map<String, dynamic>;
        final msg = json['errorMsg'] as String?;
        if (msg != null) {
          return '请求失败，状态码：${e.response?.statusCode} $msg';
        }
      } catch (_) {}
      return '请求失败，状态码：${e.response?.statusCode} $data';
    }
    return e.message ?? '网络请求失败';
  }

  /// 解析 JM 统一响应：`{code, data, errorMsg}`，data 为 AES 加密字符串。
  String _parseApiResponse(int time, String text) {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      throw const ApiException('响应不是有效的 JSON');
    }
    final code = json['code'];
    if (code != 200) {
      final msg = json['errorMsg'] as String? ?? '(服务器未返回错误信息)';
      // 业务码带出去：JM 的登录失效、限流等错误以 HTTP 200 + 业务码返回，便于上层诊断。
      throw ApiException('请求失败：$msg', apiCode: code is int ? code : null);
    }
    final data = json['data'];
    if (data is! String) {
      throw const ApiException('接口返回数据为空');
    }
    try {
      return decryptJmData(time, data);
    } catch (_) {
      throw const ApiException('响应解密失败');
    }
  }
}
