# JmBox

基于 Flutter 的 Jmcomic 第三方客户端

## 功能特性

- **浏览**：首页推荐、发现（分类 / 连载 / 每周）、关键词搜索
- **详情**：专辑信息、章节列表、评论
- **阅读**：竖排浏览、进度保存
- **本地**：书架、阅读历史、搜索历史
- **账号**：登录 / 登出、每日签到
- **设置**：主题、接口线路（域名）选择、缓存管理

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
