import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/photo_record.dart';

/// 废纸篓服务 - 管理已删除照片的记录
class TrashService {
  static const String _keyTrashPhotos = 'trash_photo_records';

  late SharedPreferences _prefs;

  /// 初始化
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// 添加到废纸篓
  Future<void> addToTrash(PhotoRecord photo) async {
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
    };
    await _prefs.setString(_keyTrashPhotos, jsonEncode(records));
  }

  /// 从废纸篓移除
  Future<void> removeFromTrash(String photoId) async {
    final records = _getTrashRecords();
    records.remove(photoId);
    await _prefs.setString(_keyTrashPhotos, jsonEncode(records));
  }

  /// 获取废纸篓中的所有照片
  List<PhotoRecord> getTrashPhotos() {
    final records = _getTrashRecords();
    final photos = <PhotoRecord>[];

    for (final entry in records.entries) {
      final data = entry.value;
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

    // 按删除时间倒序
    photos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return photos;
  }

  /// 获取废纸篓照片数量
  int getTrashCount() {
    return _getTrashRecords().length;
  }

  /// 清空废纸篓
  Future<void> clearTrash() async {
    await _prefs.remove(_keyTrashPhotos);
  }

  /// 获取过期照片（超过指定天数）
  List<PhotoRecord> getExpiredPhotos(int retentionDays) {
    final records = _getTrashRecords();
    final now = DateTime.now();
    final expired = <PhotoRecord>[];

    for (final entry in records.entries) {
      final data = entry.value;
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

  /// 获取废纸篓记录Map
  Map<String, dynamic> _getTrashRecords() {
    final jsonStr = _prefs.getString(_keyTrashPhotos);
    if (jsonStr == null) return {};
    return jsonDecode(jsonStr) as Map<String, dynamic>;
  }
}
