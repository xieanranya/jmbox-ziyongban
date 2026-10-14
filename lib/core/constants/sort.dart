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
  latest('mr'),
  like('tf'),
  totalRanking('mv'),
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

/// 分类排序选项的展示文案（筛选栏用）。
const categorySortLabels = <CategorySort, String>{
  CategorySort.latest: '最新',
  CategorySort.like: '最多喜欢',
  CategorySort.totalRanking: '总排名',
  CategorySort.monthRanking: '月排名',
};

/// 收藏排序选项的展示文案（筛选栏用）。
const favoriteSortLabels = <FavoriteSort, String>{
  FavoriteSort.favoriteTime: '收藏时间',
  FavoriteSort.updateTime: '最近更新',
};
