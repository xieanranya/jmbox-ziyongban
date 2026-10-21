# JmBox

基于 Flutter 的 Jmcomic 第三方客户端

## 发布流程（双版本）

每次发新版，两个平台一起发布：

1. 升 `pubspec.yaml` 版本号（铁律：有更改就必须升版本）
2. 构建安卓 APK → 放入 `release/JmBox_vX.Y.Z.apk`
3. 打 tag `vX.Y.Z` 推送 → CI 自动挂 APK 到 Release（占据 Latest）
4. 推送 main → CI 自动构建 iOS 未签名 IPA，并直接挂到当前版本的 Release 上（`nosign.ipa` 与 APK 同页，双版本合一；不再单独发 ios-build-N）

## 下载

- **Android**：最新版 APK 见 [Releases](https://github.com/xieanranya/jmbox-ziyongban/releases) 中标有 Latest 的 `JmBox_vX.Y.Z.apk`（debug 签名，可直接安装）
- **iOS**：未签名 IPA 见 Releases 中的 `JmBox iOS #N`（`nosign.ipa`，需 Sideloadly / AltStore 签名后安装）
- 两平台版本各自独立发布，互不影响
- 仓库首页 Latest 标记始终指向最新安卓 APK；iOS 未签名 IPA 每次推 main 自动构建发布

## 功能特性

- **浏览**：首页推荐、发现（分类 / 连载 / 每周）、关键词搜索
- **详情**：专辑信息、章节列表、评论
- **阅读**：竖排浏览、进度保存
- **画质增强（超级分辨率）**：两种引擎五档可选——
  - 经典算法：USM 锐化 / 清晰度 / 对比度 + Lanczos-3 放大（关闭 / 标准 / 增强 / 超级）
  - AI 超分：内置 Real-ESRGAN-General-x4v3 TFLite 模型（约 4.9MB，BSD-3-Clause），tflite_flutter 端上推理，GPU 优先、CPU 兜底，128×128 分块 + 14px 重叠防接缝，净 2× 输出
  - 后台处理、原图先显示增强后平滑替换；阅读器顶栏可快捷切换
- **网络**：多 API/图片 CDN 域名直连 + 启动探活自动选路；直连全部不可达时可开 HTTP 代理模式（Clash/v2ray 混合端口），设置页内置网络诊断
- **本地**：书架、阅读历史、搜索历史
- **账号**：登录 / 登出、每日签到
- **设置**：主题、画质增强、代理、接口线路（域名）选择、缓存管理

## 环境要求

- Flutter：`3.47`
- 目标平台工具链：Windows

## 快速开始

```bash
# 拉取依赖
flutter pub get

# 运行（连接设备或用 -d 指定平台）
flutter run -d windows     # Windows 桌面

# 静态分析
flutter analyze

# 构建发布包
flutter build windows      # Windows
```

## 项目结构

```
lib/
├── app/         应用外壳：路由、主题、启动流程
├── core/        基础层：网络、存储、工具、常量
├── data/        数据层：模型、仓库、依赖装配
├── features/    功能层：各业务页面与阅读器
└── shared/      复用组件
```
