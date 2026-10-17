/// 排序枚举。
library;

enum SearchSort {
  latest('mr'),
  view('mv'),
  picture('mp'),
  like('tf');

  const SearchSort(this.value);

  /// 接口参数值。
  final String value;
}

enum CategorySort {
  /// 默认（接口不带排序时的顺序，与最新一致）。
  defaultOrder('mr'),
  latest('mr'),
  like('tf'),
  totalRanking('mv'),
  pictures('mp'),

  /// 日榜：今天最多点击（接口真实榜单，mv_t）。
  todayRanking('mv_t'),

  /// 周榜：本周最多点击（mv_w）。
  weekRanking('mv_w'),

  /// 月榜：本月最多点击（mv_m）。
  monthRanking('mv_m');

  const CategorySort(this.value);

  /// 接口参数值。
  final String value;
}

enum FavoriteSort {
  favoriteTime('mr'),
  updateTime('mp');

  const FavoriteSort(this.value);

  /// 接口参数值。
  final String value;
}

/// 搜索排序选项的展示文案（筛选栏用）。
const searchSortLabels = <SearchSort, String>{
  SearchSort.latest: '最新',
  SearchSort.view: '最多点击',
  SearchSort.picture: '最多图片',
  SearchSort.like: '最多喜欢',
};

/// 分类排序选项的展示文案（首页分类排序弹窗用，顺序即弹窗顺序）。
const Map<CategorySort, String> categorySortLabels = {
  CategorySort.defaultOrder: '默认',
  CategorySort.latest: '最新',
  CategorySort.like: '心',
  CategorySort.totalRanking: '查看',
  CategorySort.todayRanking: '日榜',
  CategorySort.weekRanking: '周榜',
  CategorySort.monthRanking: '月榜',
};

/// 收藏排序选项的展示文案（筛选栏用）。
const favoriteSortLabels = <FavoriteSort, String>{
  FavoriteSort.favoriteTime: '收藏时间',
  FavoriteSort.updateTime: '最近更新',
};
