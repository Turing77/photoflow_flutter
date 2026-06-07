import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/photo_record.dart';

/// 收藏服务 - 管理收藏照片的持久化
class FavoritesService {
  static const String _keyFavorites = 'favorite_photo_ids';
  static const String _keyFavoriteDetails = 'favorite_photo_details';

  late SharedPreferences _prefs;

  /// 初始化
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// 添加收藏
  Future<void> addFavorite(PhotoRecord photo) async {
    final ids = getFavoriteIds();
    if (!ids.contains(photo.id)) {
      ids.add(photo.id);
      await _prefs.setStringList(_keyFavorites, ids);

      // 保存照片详情（用于离线显示）
      await _savePhotoDetails(photo);
    }
  }

  /// 取消收藏
  Future<void> removeFavorite(String photoId) async {
    final ids = getFavoriteIds();
    ids.remove(photoId);
    await _prefs.setStringList(_keyFavorites, ids);

    // 删除照片详情
    await _removePhotoDetails(photoId);
  }

  /// 检查是否已收藏
  bool isFavorite(String photoId) {
    return getFavoriteIds().contains(photoId);
  }

  /// 获取所有收藏的ID
  List<String> getFavoriteIds() {
    return _prefs.getStringList(_keyFavorites) ?? [];
  }

  /// 获取收藏数量
  int getFavoriteCount() {
    return getFavoriteIds().length;
  }

  /// 保存照片详情
  Future<void> _savePhotoDetails(PhotoRecord photo) async {
    final details = _getPhotoDetailsMap();
    details[photo.id] = {
      'id': photo.id,
      'uri': photo.uri,
      'filename': photo.filename,
      'createdAt': photo.createdAt.toIso8601String(),
      'width': photo.width,
      'height': photo.height,
    };
    await _prefs.setString(_keyFavoriteDetails, jsonEncode(details));
  }

  /// 删除照片详情
  Future<void> _removePhotoDetails(String photoId) async {
    final details = _getPhotoDetailsMap();
    details.remove(photoId);
    await _prefs.setString(_keyFavoriteDetails, jsonEncode(details));
  }

  /// 获取照片详情Map
  Map<String, dynamic> _getPhotoDetailsMap() {
    final jsonStr = _prefs.getString(_keyFavoriteDetails);
    if (jsonStr == null) return {};
    return jsonDecode(jsonStr) as Map<String, dynamic>;
  }

  /// 获取收藏的照片列表
  Future<List<PhotoRecord>> getFavorites() async {
    final ids = getFavoriteIds();
    if (ids.isEmpty) return [];

    final photos = <PhotoRecord>[];
    final details = _getPhotoDetailsMap();

    // 尝试从系统相册获取照片
    try {
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        hasAll: true,
      );

      if (albums.isNotEmpty) {
        final allPhotos = albums.first;

        // 加载所有照片并筛选收藏的
        int page = 0;
        bool hasMore = true;
        final loadedIds = <String>{};

        while (hasMore && loadedIds.length < ids.length) {
          final assets = await allPhotos.getAssetListPaged(
            page: page,
            size: 100,
          );

          if (assets.isEmpty) {
            hasMore = false;
            break;
          }

          for (final asset in assets) {
            if (ids.contains(asset.id) && !loadedIds.contains(asset.id)) {
              loadedIds.add(asset.id);
              final uri = await asset.getMediaUrl();
              if (uri != null) {
                photos.add(PhotoRecord(
                  id: asset.id,
                  uri: uri,
                  filename: asset.title,
                  createdAt: asset.createDateTime,
                  width: asset.width,
                  height: asset.height,
                  entity: asset,
                ));
              }
            }
          }

          page++;

          // 安全退出：如果已经找到所有收藏的照片
          if (loadedIds.length >= ids.length) break;
          // 防止无限循环
          if (page > 100) break;
        }
      }
    } catch (e) {
      debugPrint('加载收藏照片失败: $e');
    }

    // 按收藏时间倒序
    photos.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return photos;
  }

  /// 清空收藏
  Future<void> clearFavorites() async {
    await _prefs.remove(_keyFavorites);
    await _prefs.remove(_keyFavoriteDetails);
  }
}
