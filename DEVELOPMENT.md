# PhotoFlow Flutter 开发文档

## 版本信息

- **当前版本**: v1.1.0
- **构建号**: 2026.06.20
- **Flutter SDK**: ^3.11.5
- **Dart SDK**: ^3.11.5

## 项目概述

PhotoFlow 是一个本地照片整理应用，帮助用户快速浏览、收藏和删除照片。所有数据仅在设备本地处理，无需网络连接。

## 核心功能

### 1. 照片浏览
- 支持上滑删除、下滑收藏、左右滑浏览
- 每 50 张照片弹出批次确认对话框
- 支持缩放查看照片细节

### 2. 暂删区
- 删除照片前自动备份原图到应用目录
- 支持真正恢复到系统相册
- 30 天自动清理过期备份
- 容量检查：备份前检查可用空间

### 3. 统计页面
- 已查看、已收藏、已删除数量统计
- 每日整理数量图表
- 连续整理天数记录
- 设备存储空间信息

### 4. 设置页面
- 排除已收藏照片选项
- 重置统计数据
- 隐私政策查看

## 技术架构

### 目录结构
```
lib/
├── main.dart                 # 应用入口
├── models/
│   └── photo_record.dart     # 照片记录模型
├── screens/
│   ├── main_screen.dart      # 主界面（底部导航）
│   ├── image_flow_screen.dart # 照片整理界面
│   ├── stats_screen.dart     # 统计界面
│   ├── favorites_screen.dart # 收藏界面
│   ├── trash_screen.dart     # 暂删区界面
│   ├── settings_screen.dart  # 设置界面
│   └── delete_confirmation_screen.dart # 删除确认界面
├── services/
│   ├── photo_service.dart    # 照片服务
│   ├── stats_service.dart    # 统计服务
│   ├── favorites_service.dart # 收藏服务
│   ├── trash_service.dart    # 暂删区服务
│   └── storage_service.dart  # 存储服务（平台通道）
└── widgets/
    └── ...                   # 可复用组件
```

### 关键服务

#### TrashService（暂删区服务）
- **备份流程**: `prepareBackup()` → `writePreparedRecord()` → 系统删除 → `commitTrashRecord()`
- **恢复流程**: `restorePhoto()` → `saveImageWithPath()` → 验证 → 清理备份
- **状态管理**: `prepared` → `committed`（系统删除成功后）
- **容量检查**: 使用 `StorageService.getStorageInfo()` 获取可用空间

#### StatsService（统计服务）
- 使用 SharedPreferences 存储统计数据
- 支持每日、每周统计
- 连续天数计算

#### StorageService（存储服务）
- 通过平台通道获取设备存储信息
- Android 使用 `StatFs` 获取可用空间
- 支持通过 MediaStore 查询文件大小

## 数据安全

### 暂删区事务流程
1. **准备阶段**: 备份原图到临时文件，写入 `prepared` 状态记录
2. **系统删除**: 调用 `PhotoManager.editor.deleteWithIds()` 删除原图
3. **提交阶段**: 系统删除成功后，将记录改为 `committed` 状态
4. **回滚机制**: 系统删除失败时，删除临时备份和记录

### 启动扫描
- 检查 `prepared` 状态记录
- 原图仍在 → 回滚备份
- 原图不在 → 提交为可恢复记录
- 备份文件丢失 → 标记为不可恢复

### 恢复验证
- 使用 `AssetEntity.fromId()` 验证资产存在
- 3 次重试（200ms/500ms/1000ms）
- 只有验证通过才返回成功

## 构建与部署

### 开发环境
- Flutter SDK: ^3.11.5
- Dart SDK: ^3.11.5
- Android Studio / VS Code
- Android SDK

### 构建命令
```bash
# 开发构建
flutter build apk --debug

# 发布构建
flutter build apk --release
```

### 依赖包
- `photo_manager: ^3.6.4` - 相册访问
- `shared_preferences: ^2.3.4` - 本地存储
- `path_provider: ^2.1.2` - 路径获取
- `device_info_plus: ^11.3.0` - 设备信息

## 版本历史

### v1.1.0 (2026.06.20)
- 新增暂删区功能（真正恢复支持）
- 新增统计页面
- 新增九宫格暂删区布局
- 修复批量确认对话框
- 修复返回键黑屏问题
- 修复每日统计 weekday 计算
- 优化缩放最小限制
- 移除导出收藏列表功能

### v1.0.0 (2026.06.07)
- 初始版本发布
- 基础照片浏览功能
- 收藏功能
- 删除功能

## 隐私政策

PhotoFlow 不收集任何个人信息。所有照片数据仅在设备本地处理和存储，无需网络连接。

### 数据使用
- 照片访问：用于浏览和管理相册
- 应用存储：用于保存暂删区备份和缩略图
- 统计数据：用于记录整理进度（仅存储在设备本地）

### 权限使用
- 相册访问权限：用于浏览和管理照片
- 存储权限：用于备份和恢复照片

## 开发规范

### 代码风格
- 使用 Dart 官方代码风格
- 使用 `flutter analyze` 检查代码质量
- 使用 `git diff --check` 检查提交规范

### 提交规范
- 使用语义化提交信息
- 每个功能独立提交
- 修复问题时引用相关 issue

### 测试
- 真机测试优先
- 数据安全测试必须覆盖
- 边界情况测试
