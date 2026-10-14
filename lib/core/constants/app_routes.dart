/// 应用路由路径常量。
abstract final class AppRoutes {
  // ---- 底部 Tab ----
  static const home = '/home';
  static const discover = '/discover';
  static const bookshelf = '/bookshelf';
  static const profile = '/profile';

  // ---- 二级页 ----
  static const search = '/search';
  static const albumDetail = '/album';
  static const reader = '/reader';

  // ---- 列表页（每类型一个路由）----
  static const category = '/category';
  static const searchResult = '/search-result';
  static const serialization = '/serialization';
  static const weekly = '/weekly';
  static const favorites = '/favorites';

  // ---- 我的 ----
  static const settings = '/profile/settings';
  static const history = '/profile/history';
  static const dailyCheckin = '/profile/daily';
  static const about = '/profile/about';
}
