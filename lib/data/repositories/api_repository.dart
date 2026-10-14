/// API 仓库：透传全部 JM API 接口。
library;

import '../../core/constants/app_constants.dart';
import '../../core/constants/sort.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/json_utils.dart';
import '../models/album.dart';
import '../models/category.dart';
import '../models/comment.dart';
import '../models/daily.dart';
import '../models/favorite.dart';
import '../models/like.dart';
import '../models/promote.dart';
import '../models/search.dart';
import '../models/setting.dart';
import '../models/user.dart';
import '../models/week.dart';

class ApiRepository {
  ApiRepository(String? Function() apiHost) : _apiClient = ApiClient(host: apiHost);

  final ApiClient _apiClient;

  // ---- 专辑 / 章节 ----

  /// 章节列表兜底 + 排序（getAlbum / getChapter 共用，UI 侧无需再排序）：
  /// 空名章节以「第N话」兜底；列表为空时以 [fallbackId] 构造「第1话」；最后按 sort 数值升序。
  List<Series> _buildSeries(List<Series> series, int fallbackId) {
    final result = [
      for (final s in series)
        s.name.isEmpty ? Series(id: s.id, name: '第${s.sort}话', sort: s.sort) : s,
    ];
    if (result.isEmpty) {
      result.add(Series(id: fallbackId, name: '第1话', sort: '1'));
    }
    result.sort((a, b) => (int.tryParse(a.sort) ?? 0).compareTo(int.tryParse(b.sort) ?? 0));
    return result;
  }

  /// 单本series为空
  /// 连载本的任意一个chapterId也可以搜到Album信息，因此可能会看到两个JM车号不一样但series完全一致的漫画
  Future<AlbumDetail> getAlbum(int id) async {
    final detail = AlbumDetail.fromJson(await parseJsonMap(_apiClient.getAlbum(id)));
    return detail.copyWith(series: _buildSeries(detail.series, detail.id));
  }

  Future<Chapter> getChapter(int id) async {
    final chapter = Chapter.fromJson(await parseJsonMap(_apiClient.getChapter(id)));
    return chapter.copyWith(series: _buildSeries(chapter.series, chapter.id));
  }

  /// 图片解密所需的 scramble id（解析 HTML，失败回退默认值）。
  Future<int> getScrambleId(int id) async {
    final html = await _apiClient.getScrambleId(id);
    final parts = html.split('var scramble_id = ');
    if (parts.length < 2) return kAppScrambleId;
    return int.tryParse(parts[1].split(';').first.trim()) ?? kAppScrambleId;
  }

  // ---- 搜索 / 推荐 / 连载 / 分类 / 每周 ----

  Future<SearchInfo> search(String keyword, int page, SearchSort sort) async {
    final info = SearchInfo.fromJson(
      await parseJsonMap(_apiClient.search(keyword, page, sort.value)),
    );
    // 命中禁漫号（redirect_aid）时搜索列表为空，需拉取专辑详情作为单条结果。
    final aid = info.redirectAid;
    if (aid != null) {
      final detail = await getAlbum(aid);
      return SearchInfo(
        searchQuery: info.searchQuery,
        total: info.total,
        content: [AlbumBrief(id: detail.id, name: detail.name, author: detail.author.join(' '))],
        redirectAid: aid,
      );
    }
    return info;
  }

  Future<List<PromoteSection>> getPromote() async =>
      toList(await parseJsonList(_apiClient.getPromote()), PromoteSection.fromJson);

  Future<PromoteList> getPromoteList(int id, int page) async =>
      PromoteList.fromJson(await parseJsonMap(_apiClient.getPromoteList(id, page)));

  Future<List<AlbumBrief>> getSerialization(String date, String type, int page) async {
    final json = await parseJsonMap(_apiClient.getSerialization(date, type, page));
    return toList(json['list'], AlbumBrief.fromJson);
  }

  Future<CategoryInfo> getCategories() async =>
      CategoryInfo.fromJson(await parseJsonMap(_apiClient.getCategories()));

  Future<SearchInfo> getCategoriesFilter(String category, int page, CategorySort sort) async {
    // 禁漫汉化组需要使用繁体进行搜索。
    final c = category == '禁漫汉化组' ? '禁漫漢化組' : category;
    return SearchInfo.fromJson(
      await parseJsonMap(_apiClient.getCategoriesFilter(c, page, sort.value)),
    );
  }

  Future<WeekInfo> getWeekInfo() async =>
      WeekInfo.fromJson(await parseJsonMap(_apiClient.getWeekInfo()));

  Future<List<AlbumBrief>> getWeekFilter(int categoryId, String weekType) async {
    final json = await parseJsonMap(_apiClient.getWeekFilter(categoryId, weekType));
    return toList(json['list'], AlbumBrief.fromJson);
  }

  Future<AppSetting> getSetting() async =>
      AppSetting.fromJson(await parseJsonMap(_apiClient.getSetting()));

  // ---- 用户 / 收藏 / 点赞 / 评论 / 签到 ----

  Future<UserInfo> login(String username, String password) async =>
      UserInfo.fromJson(await parseJsonMap(_apiClient.login(username, password)));

  Future<void> logout() async {
    await _apiClient.logout();
  }

  Future<FavoriteInfo> getFavorite(int folderId, int page, FavoriteSort sort) async =>
      FavoriteInfo.fromJson(await parseJsonMap(_apiClient.getFavorite(folderId, page, sort.value)));

  Future<FavoriteToggleResp> toggleFavorite(int albumId) async {
    final json = await parseJsonMap(_apiClient.toggleFavorite(albumId));
    return FavoriteToggleResp.fromJson(json);
  }

  Future<LikeInfo> likeAlbum(int albumId) async =>
      LikeInfo.fromJson(await parseJsonMap(_apiClient.likeAlbum(albumId)));

  Future<CommentList> getComments(int albumId, int page) async =>
      CommentList.fromJson(await parseJsonMap(_apiClient.getComments(albumId, page)));

  Future<CommentPost> postComment(int albumId, String content, {int? commentId}) async =>
      CommentPost.fromJson(
        await parseJsonMap(_apiClient.postComment(albumId, content, commentId: commentId)),
      );

  Future<DailyInfo> getDaily(String userId) async =>
      DailyInfo.fromJson(await parseJsonMap(_apiClient.getDaily(userId)));

  Future<DailyChk> checkDaily(String userId, int dailyId) async =>
      DailyChk.fromJson(await parseJsonMap(_apiClient.checkDaily(userId, dailyId)));
}
