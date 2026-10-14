/// 分页控制器工厂。
library;

import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

/// 创建分页控制器：有总数按累计数判底，否则靠空页判底。
/// [T] 条目类型；[fetch] 返回（条目, 总数），调用方负责 `ref.onDispose(controller.dispose)`。
PagingController<int, T> pagingController<T>(
  Future<(List<T> items, int? total)> Function(int page) fetch,
) {
  int? total;
  return PagingController<int, T>(
    getNextPageKey: (state) {
      final count = state.items?.length ?? 0;
      if (total != null && count >= total!) return null;
      if (state.lastPageIsEmpty) return null;
      return state.nextIntPageKey;
    },
    fetchPage: (page) async {
      // 首页请求前清空旧总数：refresh/换筛选后避免旧值误判提前到底。
      if (page == 1) total = null;
      final (items, t) = await fetch(page);
      total = t;
      return items;
    },
  );
}
