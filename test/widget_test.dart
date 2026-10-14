// M3 应用骨架冒烟测试：验证根组件可构建、底部导航与首页渲染。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jmbox/app/app.dart';
import 'package:jmbox/app/app_state.dart';
import 'package:jmbox/data/models/config.dart';
import 'package:jmbox/data/providers.dart';
import 'package:jmbox/data/repositories/config_repository.dart';

/// 配置仓库替身：同步返回默认配置，使冒烟测试不触碰文件系统。
class _FakeConfigRepository extends ConfigRepository {
  @override
  AppConfig read() => const AppConfig();
}

void main() {
  testWidgets('JmApp 可构建并显示底部导航与首页', (WidgetTester tester) async {
    // 覆盖 bootstrap：跳过真实初始化（读配置/网络），直接进入 data 态。
    // 覆盖 configRepository：主题经同步 read() 派生，测试环境无文件 IO。
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapProvider.overrideWith((ref) async {}),
          configRepositoryProvider.overrideWithValue(_FakeConfigRepository()),
        ],
        child: const JmApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 底部导航 4 个 Tab（分类内容已收口到“发现”入口）。
    expect(find.text('首页'), findsWidgets);
    expect(find.text('发现'), findsOneWidget);
    expect(find.text('书架'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);

    // 首页 AppBar 标题
    expect(find.text('JM 漫画'), findsOneWidget);
  });
}
