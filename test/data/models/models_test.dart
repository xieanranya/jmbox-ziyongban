import 'package:flutter_test/flutter_test.dart';
import 'package:jmbox/core/constants/theme.dart';
import 'package:jmbox/data/models/album.dart';
import 'package:jmbox/data/models/category.dart';
import 'package:jmbox/data/models/comment.dart';
import 'package:jmbox/data/models/config.dart';
import 'package:jmbox/data/models/daily.dart';
import 'package:jmbox/data/models/favorite.dart';
import 'package:jmbox/data/models/like.dart';
import 'package:jmbox/data/models/promote.dart';
import 'package:jmbox/data/models/search.dart';
import 'package:jmbox/data/models/setting.dart';
import 'package:jmbox/data/models/user.dart';
import 'package:jmbox/data/models/week.dart';

void main() {
  group('专辑与章节模型', () {
    test('AlbumBrief 兼容字符串 id 并可 JSON 往返', () {
      final album = AlbumBrief.fromJson({'id': '42', 'name': '作品', 'author': '作者'});
      expect(album.id, 42);
      expect(album.name, '作品');
      expect(album.toJson(), {'id': 42, 'name': '作品', 'author': '作者'});
    });

    test('AlbumDetail 解析漂移字段、嵌套章节并保留 copyWith 其余字段', () {
      final detail = AlbumDetail.fromJson({
        'id': '7',
        'name': '长篇',
        'author': ['甲', 1, '乙'],
        'description': '简介',
        'tags': ['剧情'],
        'total_photos': '2',
        'addtime': '1700000000',
        'total_views': 10.9,
        'likes': '3',
        'series': [
          {'id': '70', 'name': '第一话', 'sort': '1'},
        ],
        'comment_total': '4',
        'liked': true,
        'is_favorite': true,
      });
      expect(detail.id, 7);
      expect(detail.author, ['甲', '乙']);
      expect(detail.totalViews, 10);
      expect(detail.series.single.id, 70);
      final replaced = detail.copyWith(
        series: const [Series(id: 71, name: '第二话', sort: '2')],
      );
      expect(replaced.series.single.id, 71);
      expect(replaced.name, detail.name);
      expect(replaced.liked, isTrue);
    });

    test('Chapter 解析图片列表并只替换章节列表', () {
      final chapter = Chapter.fromJson({
        'id': 9,
        'images': ['1.webp', 2, '3.webp'],
        'series': const [],
      });
      expect(chapter.images, ['1.webp', '3.webp']);
      final replaced = chapter.copyWith(
        series: const [Series(id: 9, name: '第1话', sort: '1')],
      );
      expect(replaced.images, chapter.images);
      expect(replaced.series.single.id, 9);
    });
  });

  group('分类、推荐与搜索模型', () {
    test('分类嵌套结构过滤非法成员', () {
      final info = CategoryInfo.fromJson({
        'categories': [
          {
            'id': '1',
            'name': '主题',
            'slug': 'topic',
            'total_albums': '12',
            'sub_categories': [
              {'CID': '2', 'name': '子类', 'slug': 'sub'},
              'bad',
            ],
          },
        ],
        'blocks': [
          {
            'title': '标签',
            'content': ['A', 1, 'B'],
          },
        ],
      });
      expect(info.categories.single.totalAlbums, 12);
      expect(info.categories.single.subCategories, [
        const CategorySub(id: 2, name: '子类', slug: 'sub'),
      ]);
      expect(info.blocks.single.content, ['A', 'B']);
    });

    test('推荐标题截掉箭头提示后缀', () {
      final section = PromoteSection.fromJson({
        'id': 3,
        'title': '連載更新 → 右滑看更多',
        'slug': 'latest',
        'type': 'promote',
        'content': [
          {'id': 1, 'name': 'A', 'author': 'B'},
        ],
      });
      expect(section.title, '連載更新');
      expect(section.content.single.id, 1);

      final list = PromoteList.fromJson({
        'total': '1',
        'list': [
          {'id': 1, 'name': 'A', 'author': 'B'},
        ],
      });
      expect(list.total, 1);
      expect(list.list, hasLength(1));
    });

    test('搜索 redirect_aid 缺失时为 null，存在时兼容字符串', () {
      expect(SearchInfo.fromJson(const {}).redirectAid, isNull);
      final info = SearchInfo.fromJson({
        'search_query': '42',
        'total': '1',
        'content': const [],
        'redirect_aid': '42',
      });
      expect(info.redirectAid, 42);
      expect(info.total, 1);
    });
  });

  group('配置与服务设置模型', () {
    test('AppConfig JSON 往返并对未知主题回退 system', () {
      const config = AppConfig(
        username: 'alice',
        password: 'secret',
        apiHost: 'https://api.test',
        imageAuto: false,
        imageHost: 'https://img.test',
        autoCheckin: true,
        themeSetting: ThemeSetting.dark,
      );
      final restored = AppConfig.fromJson(config.toJson());
      expect(restored.username, 'alice');
      expect(restored.imageAuto, isFalse);
      expect(restored.autoCheckin, isTrue);
      expect(restored.themeSetting, ThemeSetting.dark);
      expect(AppConfig.fromJson({'theme_setting': 'future'}).themeSetting, ThemeSetting.system);
    });

    test('copyWith 只改指定字段并允许用空串清理凭据', () {
      const original = AppConfig(username: 'alice', password: 'secret');
      final changed = original.copyWith(password: '', autoCheckin: true);
      expect(changed.username, 'alice');
      expect(changed.password, '');
      expect(changed.autoCheckin, isTrue);
    });

    test('AppSetting 兼容两套字段名与数字 shunt key', () {
      final primary = AppSetting.fromJson({
        'jm3_version': '2.1.4',
        'img_host': 'https://img.test',
        'app_shunts': [
          {'key': 2, 'title': '线路二'},
        ],
      });
      expect(primary.apiVersion, '2.1.4');
      expect(primary.imageHost, 'https://img.test');
      expect(primary.shunts.single.id, '2');
      expect(primary.shunts.single.name, '线路二');

      final legacy = AppSetting.fromJson({'version': '1', 'imgHost': 'legacy'});
      expect(legacy.apiVersion, '1');
      expect(legacy.imageHost, 'legacy');
    });
  });

  group('评论、签到与用户模型', () {
    test('评论正文移除 div 包裹并递归解析回复', () {
      final comment = CommentInfo.fromJson({
        'CID': '1',
        'username': 'alice',
        'content': '<div class="x">正文</div>',
        'addtime': 'now',
        'replys': [
          {'CID': 2, 'content': '回复'},
        ],
      });
      expect(comment.content, '正文');
      expect(comment.replys.single.cid, 2);
      expect(CommentInfo.fromJson({'content': '<span>原样</span>'}).content, '<span>原样</span>');
      expect(
        CommentList.fromJson({
          'total': '1',
          'list': [commentToJson(comment)],
        }).total,
        1,
      );
    });

    test('签到记录按周解析并保留未来日期 null 状态', () {
      final info = DailyInfo.fromJson({
        'daily_id': '5',
        'currentProgress': '28.6%',
        'record': [
          [
            {'date': '01', 'signed': true, 'bonus': true},
            {'date': '02', 'signed': null},
          ],
          'bad week',
        ],
      });
      expect(info.dailyId, 5);
      expect(info.record, hasLength(2));
      expect(info.record.first.first.bonus, isTrue);
      expect(info.record.first.last.signed, isNull);
      expect(info.record.last, isEmpty);
      expect(DailyChk.fromJson({'msg': 'ok'}).msg, 'ok');
    });

    test('用户数值字段兼容字符串与浮点数', () {
      final user = UserInfo.fromJson({
        'uid': '8',
        'username': 'alice',
        'email': 'a@example.com',
        'coin': 3.8,
        'album_favorites': '4',
        'album_favorites_max': 10,
        'level_name': 'Lv1',
        'level': '1',
        'nextLevelExp': '100',
        'exp': 20,
      });
      expect(user.uid, 8);
      expect(user.coin, 3);
      expect(user.albumFavorites, 4);
      expect(user.nextLevelExp, 100);
    });
  });

  group('每周、收藏与点赞模型', () {
    test('每周数据解析且分类值对象可比较', () {
      final info = WeekInfo.fromJson({
        'categories': [
          {'id': '1', 'title': '本周', 'time': '2026-09'},
        ],
        'type': [
          {'id': 'manga', 'title': '漫画'},
        ],
      });
      expect(info.categories.single, const WeekCategory(id: 1, title: '本周', time: '2026-09'));
      expect(info.weekTypes.single.id, 'manga');
    });

    test('收藏、切换与点赞响应解析', () {
      final favorites = FavoriteInfo.fromJson({
        'total': '2',
        'count': 1,
        'list': [
          {'id': 1, 'name': 'A', 'author': 'B'},
        ],
      });
      expect(favorites.total, 2);
      expect(favorites.list.single.name, 'A');
      expect(
        FavoriteToggleResp.fromJson({'status': 'ok', 'msg': 'done', 'type': 'add'}).type,
        'add',
      );
      expect(LikeInfo.fromJson({'status': 'success', 'msg': 'liked'}).status, 'success');
    });
  });
}

Map<String, dynamic> commentToJson(CommentInfo comment) => {
  'CID': comment.cid,
  'username': comment.username,
  'content': comment.content,
  'addtime': comment.addtime,
  'replys': const [],
};
