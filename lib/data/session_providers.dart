/// 会话控制器：登录态 + 登录/登出（带凭据持久化）。
///
/// 登录态是跨 feature 全局状态（app 启动自动登录、签到页、详情页、shared 登录面板
/// 均依赖），故归 data 层而非 features/profile；不放 data/providers.dart 是因为
/// 该文件只做纯仓库装配，这里是带副作用的业务逻辑。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/user.dart';
import '../../data/providers.dart';

class SessionController extends AsyncNotifier<UserInfo?> {
  @override
  Future<UserInfo?> build() async => null;

  /// 登录：成功后更新状态并持久化凭据；失败抛异常由调用方提示。
  Future<UserInfo> signIn(String username, String password) async {
    final user = await ref.read(apiRepositoryProvider).login(username, password);
    state = AsyncData(user);
    try {
      ref.read(configRepositoryProvider).updateWith(username: username, password: password);
    } catch (_) {
      // 持久化失败不影响本次登录态。
    }
    return user;
  }

  /// 退出登录：调服务端登出接口 + 清空本地登录态与密码（保留用户名）。
  Future<void> signOut() async {
    try {
      await ref.read(apiRepositoryProvider).logout();
    } catch (_) {
      // 服务端登出失败可容忍，本地清理仍继续。
    }
    state = const AsyncData(null);
    try {
      ref.read(configRepositoryProvider).updateWith(password: '');
    } catch (_) {
      // 凭据清理失败不影响本次登出。
    }
  }
}

final sessionProvider = AsyncNotifierProvider<SessionController, UserInfo?>(SessionController.new);
