# PhotoSwipe 📸

一款以「短视频流」为交互范式的手机相册整理工具。用户通过上下滑动浏览随机抽取的照片流，上滑删除、下滑收藏，快速完成相册整理。

![Flutter](https://img.shields.io/badge/Flutter-3.41-blue)
![Dart](https://img.shields.io/badge/Dart-3.11-blue)
![Android](https://img.shields.io/badge/Android-10+-green)
![License](https://img.shields.io/badge/License-MIT-purple)

## ✨ 功能特性

### 🎴 图像流（主页）
- **全屏沉浸式浏览** - 照片占满整个屏幕
- **手势操作**：
  - ⬆️ 上滑 → 删除照片（标记待删除）
  - ⬇️ 下滑 → 收藏照片
  - ⬅️ 向左滑 → 上一张
  - ➡️ 向右滑 → 下一张
  - 👆 点击 → 放大查看（支持双指缩放）
- **PPT 平移动画** - 图片像排好的卡片一样滑动
- **随机抽取** - 从相册随机抽取照片，避免重复
- **删除确认** - 退出时批量确认删除

### ❤️ 收藏夹
- **收藏列表** - 显示所有收藏的照片
- **智能分组** - 按时间/地点自动分组
- **取消收藏** - 长按可取消收藏
- **数据持久化** - 收藏数据本地保存

### 📊 整理统计
- **四项核心指标** - 已查看/已收藏/已删除/已释放空间
- **连续天数** - 连续整理天数统计
- **每日条形图** - 最近 7 天整理数量
- **操作分布** - 保留/收藏/删除比例

### 🗑️ 废纸篓
- **删除记录** - 记录所有已删除照片
- **恢复功能** - 可恢复误删的照片
- **永久删除** - 支持永久删除
- **自动清理** - 30 天后自动清理

### ⚙️ 设置
- **相册权限管理** - 相册/位置权限
- **整理设置** - 排除已删除/已收藏照片
- **随机算法** - 完全随机/久违优先/时间倒序
- **每日目标** - 设置每日整理目标
- **废纸篓设置** - 自动清理周期
- **通知设置** - 整理提醒

## 🚀 快速开始

### 环境要求

- Flutter 3.41+
- Dart 3.11+
- Android 10+ 或 iOS 16+

### 安装依赖

```bash
flutter pub get
```

### 运行应用

```bash
# 开发模式
flutter run

# 构建 APK
flutter build apk --debug

# 构建 Release
flutter build apk --release
```

### 安装到手机

```bash
# 连接手机后执行
adb install build/app/outputs/flutter-apk/app-debug.apk
```

## 📁 项目结构

```
lib/
├── main.dart                          # 应用入口
├── models/
│   ├── photo_record.dart              # 照片数据模型
│   ├── favorite_collection.dart       # 收藏集模型
│   └── sorting_session.dart           # 整理会话模型
├── screens/
│   ├── main_screen.dart               # 主框架（底部导航）
│   ├── image_flow_screen.dart         # 图像流页（主页）
│   ├── photo_viewer_screen.dart       # 照片查看页
│   ├── favorites_screen.dart          # 收藏夹页
│   ├── stats_screen.dart              # 统计页
│   ├── settings_screen.dart           # 设置页
│   ├── trash_screen.dart              # 废纸篓页
│   └── delete_confirmation_screen.dart # 删除确认页
├── services/
│   ├── photo_service.dart             # 相册服务
│   ├── stats_service.dart             # 统计服务
│   ├── favorites_service.dart         # 收藏服务
│   └── trash_service.dart             # 废纸篓服务
└── widgets/
    └── photo_details_drawer.dart      # 照片详情抽屉
```

## 🛠️ 技术栈

| 技术 | 用途 |
|------|------|
| **Flutter** | UI 框架 |
| **photo_manager** | 相册访问 |
| **shared_preferences** | 本地存储 |
| **InteractiveViewer** | 图片缩放 |

## 📋 依赖

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  photo_manager: ^3.6.4
  shared_preferences: ^2.3.4
```

## 🎨 设计规范

| 元素 | 颜色 | 用途 |
|------|------|------|
| 主题色 | `#7F77DD` | 紫色，主要操作 |
| 删除色 | `#E24B4A` | 红色，删除操作 |
| 收藏色 | `#639922` | 绿色，收藏操作 |
| 背景色 | `#000000` | 黑色，照片区域 |

## 📐 手势阈值

| 手势 | 阈值 | 速度要求 |
|------|------|----------|
| 左右切换 | 15% 屏幕宽度 | 500px/s |
| 上滑删除 | 15% 屏幕高度 | 500px/s |
| 下滑收藏 | 15% 屏幕高度 | 500px/s |

## 🔧 配置说明

### Android 权限

在 `android/app/src/main/AndroidManifest.xml` 中添加：

```xml
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
```

### iOS 权限

在 `ios/Runner/Info.plist` 中添加：

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>需要访问相册以浏览和整理照片</string>
```

## 📝 更新日志

### v1.0.0 (2026-06-07)
- ✅ 图像流基础功能
- ✅ 手势操作（上下左右滑动）
- ✅ PPT 平移动画
- ✅ 收藏夹功能
- ✅ 统计页面
- ✅ 废纸篓功能
- ✅ 设置页面
- ✅ 数据持久化

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

本项目采用 MIT 许可证

## 👨‍💻 作者

- **TuringAI** - [GitHub](https://github.com/Turing77)

---

<p align="center">
  Made with ❤️ by TuringAI
</p>
