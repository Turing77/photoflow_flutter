import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/photo_record.dart';
import 'storage_service.dart';

/// 暂删区服务 - 管理已删除照片的备份和记录
class TrashService {
  static const String _keyTrashPhotos = 'trash_photo_records';

  late SharedPreferences _prefs;
  late Directory _backupDir;
  late Directory _thumbnailDir;

  /// 初始化
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final appDir = await getApplicationSupportDirectory();
    _backupDir = Directory('${appDir.path}/trash_backups');
    _thumbnailDir = Directory('${appDir.path}/trash_thumbnails');

    // 确保目录存在
    if (!await _backupDir.exists()) {
      await _backupDir.create(recursive: true);
    }
    if (!await _thumbnailDir.exists()) {
      await _thumbnailDir.create(recursive: true);
    }

    // 启动扫描：恢复 prepared 状态或标记不可恢复
    await _scanOnStartup();
  }

  /// 启动扫描：处理 prepared 状态记录
  Future<void> _scanOnStartup() async {
    final records = _getTrashRecords();
    bool changed = false;
    final idsToRemove = <String>[];

    for (final entry in records.entries) {
      final data = entry.value;
      final state = data['state'] as String? ?? 'committed';
      final backupPath = data['backupPath'] as String?;

      if (state == 'prepared') {
        // prepared 状态：检查原图是否还在
        final photoId = data['id'] as String;
        bool? assetExists;

        try {
          final asset = await AssetEntity.fromId(photoId);
          // asset != null 说明相册资产仍存在
          assetExists = asset != null;
        } catch (e) {
          // 查询失败，不等于文件不存在，保持 prepared 状态
          debugPrint('检查原图失败（保持 prepared 状态）: $e');
          continue;
        }

        if (assetExists == true) {
          // 原图还在，回滚备份
          await _cleanupFiles(backupPath, data['thumbnailPath'] as String?);
          idsToRemove.add(entry.key);
          changed = true;
        } else if (assetExists == false) {
          // 原图不在了，提交为可恢复记录
          if (backupPath != null) {
            final tempFile = File(backupPath);
            if (await tempFile.exists()) {
              // rename 临时文件为正式文件
              final ext = _getExtension(data['filename'] as String? ?? 'photo.jpg');
              final finalPath = '${_backupDir.path}/$photoId$ext';
              try {
                await tempFile.rename(finalPath);
                data['backupPath'] = finalPath;
                data['state'] = 'committed';
                data['restorable'] = true;
              } catch (e) {
                // rename 失败，保持 prepared 状态
                debugPrint('rename 备份文件失败: $e');
                continue;
              }
            } else {
              // 备份文件也丢了，标记不可恢复
              data['state'] = 'committed';
              data['restorable'] = false;
            }
          } else {
            data['state'] = 'committed';
            data['restorable'] = false;
          }
          changed = true;
        }
      } else if (state == 'committed') {
        // committed 状态：检查备份是否存在
        final restorable = data['restorable'] as bool? ?? true;
        if (restorable && backupPath != null) {
          final file = File(backupPath);
          if (!await file.exists()) {
            data['restorable'] = false;
            changed = true;
          }
        }
      }
    }

    // 统一删除需要移除的记录
    for (final id in idsToRemove) {
      records.remove(id);
    }

    if (changed) {
      await _prefs.setString(_keyTrashPhotos, jsonEncode(records));
    }
  }

  /// 获取文件扩展名
  String _getExtension(String filename) {
    final parts = filename.split('.');
    return parts.length > 1 ? '.${parts.last}' : '.jpg';
  }

  /// 备份原图到临时文件（准备阶段）
  /// 返回临时文件路径，失败返回 null
  Future<String?> prepareBackup(PhotoRecord photo) async {
    try {
      // 从系统获取原图文件
      final asset = await AssetEntity.fromId(photo.id);
      if (asset == null) return null;

      final file = await asset.file;
      if (file == null || !await file.exists()) return null;

      // 复制到临时文件
      final ext = _getExtension(photo.filename ?? 'photo.jpg');
      final tempPath = '${_backupDir.path}/${photo.id}_tmp${ext}';
      final tempFile = await file.copy(tempPath);

      // 验证文件长度
      final sourceLength = await file.length();
      final destLength = await tempFile.length();
      if (sourceLength != destLength) {
        await tempFile.delete();
        debugPrint('备份完整性校验失败：源文件 $sourceLength 字节，目标 $destLength 字节');
        return null;
      }

      return tempPath;
    } catch (e) {
      debugPrint('备份原图失败: $e');
      return null;
    }
  }

  /// 生成缩略图
  Future<String?> generateThumbnail(PhotoRecord photo) async {
    try {
      final asset = await AssetEntity.fromId(photo.id);
      if (asset == null) return null;

      final thumbData = await asset.thumbnailDataWithSize(
        const ThumbnailSize(200, 200),
      );
      if (thumbData == null) return null;

      final thumbPath = '${_thumbnailDir.path}/${photo.id}.jpg';
      final thumbFile = File(thumbPath);
      await thumbFile.writeAsBytes(thumbData);
      return thumbPath;
    } catch (e) {
      debugPrint('生成缩略图失败: $e');
      return null;
    }
  }

  /// 写入 prepared 状态记录（系统删除前调用）
  Future<void> writePreparedRecord(
    PhotoRecord photo, {
    required String tempBackupPath,
    String? thumbnailPath,
  }) async {
    final records = _getTrashRecords();
    records[photo.id] = {
      'id': photo.id,
      'uri': photo.uri,
      'filename': photo.filename,
      'createdAt': photo.createdAt.toIso8601String(),
      'deletedAt': DateTime.now().toIso8601String(),
      'width': photo.width,
      'height': photo.height,
      'fileSize': photo.fileSize,
      'backupPath': tempBackupPath,
      'thumbnailPath': thumbnailPath,
      'state': 'prepared',
      'restorable': false, // prepared 状态暂不可恢复
    };
    await _prefs.setString(_keyTrashPhotos, jsonEncode(records));
  }

  /// 提交暂删记录（系统删除成功后调用）
  Future<bool> commitTrashRecord(String photoId) async {
    final records = _getTrashRecords();
    final data = records[photoId];
    if (data == null) return false;

    final tempBackupPath = data['backupPath'] as String?;
    if (tempBackupPath == null) return false;

    final tempFile = File(tempBackupPath);
    if (!await tempFile.exists()) {
      // 临时文件不存在，标记不可恢复
      data['state'] = 'committed';
      data['restorable'] = false;
      await _prefs.setString(_keyTrashPhotos, jsonEncode(records));
      return false;
    }

    try {
      // 将临时文件重命名为正式文件
      final ext = _getExtension(data['filename'] as String? ?? 'photo.jpg');
      final finalPath = '${_backupDir.path}/$photoId$ext';
      await tempFile.rename(finalPath);
      data['backupPath'] = finalPath;
      data['state'] = 'committed';
      data['restorable'] = true;
      await _prefs.setString(_keyTrashPhotos, jsonEncode(records));
      return true;
    } catch (e) {
      debugPrint('提交暂删记录失败: $e');
      // rename 失败，保持 prepared 状态
      return false;
    }
  }

  /// 回滚备份（系统删除失败时调用）
  Future<void> rollbackBackup(String photoId) async {
    final records = _getTrashRecords();
    final data = records[photoId];
    if (data == null) return;

    await _cleanupFiles(
      data['backupPath'] as String?,
      data['thumbnailPath'] as String?,
    );

    records.remove(photoId);
    await _prefs.setString(_keyTrashPhotos, jsonEncode(records));
  }

  /// 清理文件（内部方法，不更新记录）
  Future<void> _cleanupFiles(String? backupPath, String? thumbnailPath) async {
    if (backupPath != null) {
      try {
        final file = File(backupPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('删除备份文件失败: $e');
      }
    }
    if (thumbnailPath != null) {
      try {
        final file = File(thumbnailPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('删除缩略图失败: $e');
      }
    }
  }

  /// 检查整批备份是否可行（容量检查）
  Future<bool> canBackupBatch(List<PhotoRecord> photos) async {
    int totalSize = 0;
    for (final photo in photos) {
      totalSize += photo.fileSize;
    }

    // 使用平台通道获取可用空间
    final storageInfo = await StorageService.getStorageInfo();
    final freeSpace = storageInfo['free'] ?? 0;

    // 留 200MB 缓冲
    final available = freeSpace - 200 * 1024 * 1024;
    return available > totalSize;
  }

  /// 恢复照片到系统相册
  /// 返回 true 表示恢复成功（即使清理失败）
  Future<bool> restorePhoto(String photoId) async {
    final records = _getTrashRecords();
    final data = records[photoId];
    if (data == null) return false;

    final restorable = data['restorable'] as bool? ?? false;
    if (!restorable) {
      debugPrint('照片不可恢复');
      return false;
    }

    final backupPath = data['backupPath'] as String?;
    if (backupPath == null) return false;

    final backupFile = File(backupPath);
    if (!await backupFile.exists()) {
      debugPrint('备份文件不存在');
      return false;
    }

    try {
      // 检查备份文件
      final backupFile = File(backupPath);
      if (!await backupFile.exists()) {
        debugPrint('恢复失败：备份文件不存在: $backupPath');
        return false;
      }

      final fileSize = await backupFile.length();
      debugPrint('恢复照片: ${data['filename']}, 路径: $backupPath, 大小: $fileSize bytes');

      final filename = data['filename'] as String? ?? 'restored_photo.jpg';
      final createdAt = DateTime.tryParse(data['createdAt'] ?? '');

      // 使用 saveImageWithPath 恢复到相册
      final startTime = DateTime.now();
      debugPrint('[${startTime.toIso8601String()}] 开始调用 saveImageWithPath...');
      AssetEntity? asset;
      try {
        asset = await PhotoManager.editor.saveImageWithPath(
          backupPath,
          title: filename,
          creationDate: createdAt,
        );
        final endTime = DateTime.now();
        final duration = endTime.difference(startTime);
        debugPrint('[${endTime.toIso8601String()}] saveImageWithPath 返回: ${asset?.id ?? "null"}, 耗时: ${duration.inMilliseconds}ms');
      } catch (e) {
        final endTime = DateTime.now();
        final duration = endTime.difference(startTime);
        debugPrint('[${endTime.toIso8601String()}] saveImageWithPath 异常: $e, 耗时: ${duration.inMilliseconds}ms');
        return false;
      }

      if (asset == null) {
        debugPrint('恢复失败：saveImageWithPath 返回 null');
        return false;
      }

      // 验证恢复的资产确实存在（带重试）
      const retryDelays = [200, 500, 1000]; // ms
      bool verified = false;

      for (final delay in retryDelays) {
        await Future.delayed(Duration(milliseconds: delay));
        try {
          final verifyAsset = await AssetEntity.fromId(asset.id);
          if (verifyAsset != null) {
            verified = true;
            debugPrint('恢复验证成功: ${asset.id}');
            break;
          }
        } catch (e) {
          debugPrint('恢复验证异常: $e');
        }
        debugPrint('恢复验证重试: ${delay}ms 后仍未找到资产 ${asset.id}');
      }

      if (verified) {
        // 恢复成功，立即移除记录（清理失败不影响恢复结果）
        records.remove(photoId);
        await _prefs.setString(_keyTrashPhotos, jsonEncode(records));

        // 异步清理文件（失败不影响恢复）
        _cleanupFiles(backupPath, data['thumbnailPath'] as String?).catchError((e) {
          debugPrint('清理恢复后的备份文件失败: $e');
        });

        return true;
      } else {
        debugPrint('恢复验证失败：重试后仍未找到资产 ${asset.id}');
        return false;
      }
    } catch (e) {
      debugPrint('恢复失败: $e');
      return false;
    }
  }

  /// 永久删除备份（返回释放的字节数，失败返回 -1）
  Future<int> permanentlyDelete(String photoId) async {
    final records = _getTrashRecords();
    final data = records[photoId];
    if (data == null) return -1;

    final backupPath = data['backupPath'] as String?;
    final thumbnailPath = data['thumbnailPath'] as String?;

    // 计算文件大小
    final freedBytes = await _calculateFileSize(backupPath);

    // 清理文件
    bool cleanupSuccess = true;
    if (backupPath != null) {
      try {
        final file = File(backupPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('删除备份文件失败: $e');
        cleanupSuccess = false;
      }
    }
    if (thumbnailPath != null) {
      try {
        final file = File(thumbnailPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('删除缩略图失败: $e');
        // 缩略图删除失败不影响主流程
      }
    }

    // 只有备份文件清理成功才删除记录
    if (cleanupSuccess) {
      records.remove(photoId);
      await _prefs.setString(_keyTrashPhotos, jsonEncode(records));
      return freedBytes;
    } else {
      // 清理失败，保留记录
      debugPrint('备份文件清理失败，保留记录');
      return -1;
    }
  }

  /// 计算文件大小
  Future<int> _calculateFileSize(String? path) async {
    if (path == null) return 0;
    try {
      final file = File(path);
      if (await file.exists()) {
        return await file.length();
      }
    } catch (e) {
      debugPrint('获取文件大小失败: $e');
    }
    return 0;
  }

  /// 获取暂删区中的所有照片
  List<PhotoRecord> getTrashPhotos() {
    final records = _getTrashRecords();
    final photos = <PhotoRecord>[];

    for (final entry in records.entries) {
      final data = entry.value;
      final state = data['state'] as String? ?? 'committed';
      // 只返回 committed 状态的记录
      if (state == 'committed') {
        photos.add(PhotoRecord(
          id: data['id'] ?? '',
          uri: data['uri'] ?? '',
          filename: data['filename'],
          createdAt: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
          width: data['width'] ?? 0,
          height: data['height'] ?? 0,
          fileSize: data['fileSize'] ?? 0,
        ));
      }
    }

    // 按删除时间倒序
    photos.sort((a, b) {
      final aDeletedAt = records[a.id]?['deletedAt'];
      final bDeletedAt = records[b.id]?['deletedAt'];
      if (aDeletedAt == null || bDeletedAt == null) return 0;
      return DateTime.tryParse(bDeletedAt ?? '')?.compareTo(
             DateTime.tryParse(aDeletedAt ?? '') ?? DateTime.now()) ?? 0;
    });
    return photos;
  }

  /// 获取暂删区照片的缩略图路径
  String? getTrashPhotoPath(String photoId) {
    final records = _getTrashRecords();
    final data = records[photoId];
    return data?['thumbnailPath'] as String?;
  }

  /// 检查照片是否可恢复
  bool isRestorable(String photoId) {
    final records = _getTrashRecords();
    final data = records[photoId];
    if (data == null) return false;
    final state = data['state'] as String? ?? 'committed';
    if (state != 'committed') return false;
    return data['restorable'] as bool? ?? false;
  }

  /// 获取暂删区照片数量
  int getTrashCount() {
    final records = _getTrashRecords();
    return records.entries.where((e) {
      final state = e.value['state'] as String? ?? 'committed';
      return state == 'committed';
    }).length;
  }

  /// 清空暂删区（返回释放的字节数）
  Future<int> clearTrash() async {
    final records = _getTrashRecords();
    int totalFreed = 0;
    final List<String> failedIds = [];

    for (final entry in records.entries) {
      final state = entry.value['state'] as String? ?? 'committed';
      if (state != 'committed') continue;

      final freed = await permanentlyDelete(entry.key);
      if (freed >= 0) {
        totalFreed += freed;
      } else {
        failedIds.add(entry.key);
      }
    }

    return totalFreed;
  }

  /// 获取过期照片（超过指定天数）
  List<PhotoRecord> getExpiredPhotos(int retentionDays) {
    final records = _getTrashRecords();
    final now = DateTime.now();
    final expired = <PhotoRecord>[];

    for (final entry in records.entries) {
      final data = entry.value;
      final state = data['state'] as String? ?? 'committed';
      if (state != 'committed') continue;

      final deletedAt = DateTime.tryParse(data['deletedAt'] ?? '');
      if (deletedAt != null) {
        final daysSinceDeleted = now.difference(deletedAt).inDays;
        if (daysSinceDeleted >= retentionDays) {
          expired.add(PhotoRecord(
            id: data['id'] ?? '',
            uri: data['uri'] ?? '',
            filename: data['filename'],
            createdAt: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
            width: data['width'] ?? 0,
            height: data['height'] ?? 0,
            fileSize: data['fileSize'] ?? 0,
          ));
        }
      }
    }

    return expired;
  }

  /// 清理过期照片（默认30天，返回释放的字节数）
  Future<int> cleanupExpiredPhotos({int retentionDays = 30}) async {
    final expired = getExpiredPhotos(retentionDays);
    if (expired.isEmpty) return 0;

    int totalFreed = 0;
    for (final photo in expired) {
      final freed = await permanentlyDelete(photo.id);
      if (freed > 0) totalFreed += freed;
    }

    return totalFreed;
  }

  /// 获取暂删区记录Map
  Map<String, dynamic> _getTrashRecords() {
    final jsonStr = _prefs.getString(_keyTrashPhotos);
    if (jsonStr == null) return {};
    return jsonDecode(jsonStr) as Map<String, dynamic>;
  }
}
