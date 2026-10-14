/// 应用路由表：四个底部 Tab 用 indexedStack 承载，二级页挂在根级。
library;

import 'package:go_router/go_router.dart';

import '../features/album_detail/album_detail_page.dart';
import '../features/discover/category_page.dart';
import '../features/discover/discover_page.dart';
import '../features/discover/serialization_page.dart';
import '../features/discover/weekly_page.dart';
import '../features/bookshelf/bookshelf_page.dart';
import '../features/profile/checkin/checkin_page.dart';
import '../features/favorite/favorite_page.dart';
import '../features/history/history_page.dart';
import '../features/home/home_page.dart';
import '../features/profile/about/about_page.dart';
import '../features/profile/profile_page.dart';
import '../features/reader/reader_page.dart';
import '../features/search/search_page.dart';
import '../features/search/search_result_page.dart';
import '../features/settings/settings_page.dart';
import '../core/constants/app_routes.dart';
import 'shell.dart';

final appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: AppRoutes.home, builder: (_, _) => const HomePage())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: AppRoutes.discover, builder: (_, _) => const DiscoverPage())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: AppRoutes.bookshelf, builder: (_, _) => const BookshelfPage())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: AppRoutes.profile, builder: (_, _) => const ProfilePage())],
        ),
      ],
    ),
    // ---- 个人 Tab 二级页：根级路由，全屏无底部导航 ----
    GoRoute(path: AppRoutes.settings, builder: (_, _) => const SettingsPage()),
    GoRoute(path: AppRoutes.history, builder: (_, _) => const HistoryPage()),
    GoRoute(path: AppRoutes.dailyCheckin, builder: (_, _) => const CheckinPage()),
    GoRoute(path: AppRoutes.about, builder: (_, _) => const AboutPage()),
    GoRoute(path: AppRoutes.search, builder: (_, _) => const SearchPage()),
    GoRoute(
      path: AppRoutes.category,
      builder: (_, state) => CategoryPage(query: state.extra! as CategoryQuery),
    ),
    GoRoute(
      path: AppRoutes.searchResult,
      builder: (_, state) => SearchResultPage(keyword: state.extra! as String),
    ),
    GoRoute(
      path: AppRoutes.serialization,
      builder: (_, state) {
        final (date, title) = state.extra! as (String, String);
        return SerializationPage(initialDate: date, title: title);
      },
    ),
    GoRoute(path: AppRoutes.weekly, builder: (_, _) => const WeeklyPage()),
    GoRoute(path: AppRoutes.favorites, builder: (_, _) => const FavoritePage()),
    GoRoute(
      path: '${AppRoutes.albumDetail}/:id',
      builder: (_, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '');
        return AlbumDetailPage(id: id);
      },
    ),
    GoRoute(
      path: '${AppRoutes.reader}/:albumId/:chapterId',
      builder: (_, state) {
        final albumId = int.tryParse(state.pathParameters['albumId'] ?? '');
        final chapterId = int.tryParse(state.pathParameters['chapterId'] ?? '');
        return ReaderPage(albumId: albumId, chapterId: chapterId);
      },
    ),
  ],
);

