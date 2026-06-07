import 'dart:math';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/photo_record.dart';

class PhotoService {
  static const int pageSize = 50;

  AssetPathEntity? _allPhotos;
  int _totalCount = 0;
  final Set<int> _usedIndices = {};
  final Random _random = Random();

  /// 请求权限
  Future<PermissionState> requestPermission() async {
    return await PhotoManager.requestPermissionExtend();
  }

  /// 初始化相册
  Future<void> _initAlbum() async {
    if (_allPhotos != null) return;

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      hasAll: true,
    );

    if (albums.isEmpty) return;

    _allPhotos = albums.first;

    // 获取总数 - 使用 getAssetListPaged 来估算
    // 先尝试获取一批来确定总数
    final testAssets = await _allPhotos!.getAssetListPaged(page: 0, size: 1);
    if (testAssets.isNotEmpty) {
      // 使用一个较大的数作为上限，实际会动态调整
      _totalCount = 10000; // 临时值，后续会根据实际调整
    }
  }

  /// 生成随机索引列表
  List<int> _generateRandomIndices(int count) {
    final indices = <int>[];
    final available = <int>[];

    // 收集未使用的索引
    for (int i = 0; i < _totalCount; i++) {
      if (!_usedIndices.contains(i)) {
        available.add(i);
      }
    }

    // 如果可用索引不足，重置
    if (available.length < count) {
      _usedIndices.clear();
      available.clear();
      for (int i = 0; i < _totalCount; i++) {
        available.add(i);
      }
    }

    // 随机选择
    final shuffled = List<int>.from(available)..shuffle(_random);
    final selected = shuffled.take(count).toList();

    // 记录已使用
    _usedIndices.addAll(selected);

    return selected;
  }

  /// 加载随机照片
  Future<List<PhotoRecord>> loadPhotos({int page = 0}) async {
    final permission = await requestPermission();
    if (!permission.isAuth && permission != PermissionState.limited) {
      throw Exception('需要相册访问权限才能浏览照片');
    }

    await _initAlbum();
    if (_allPhotos == null) return [];

    // 使用分页方式加载，但在多个随机位置加载
    final photos = <PhotoRecord>[];
    final random = Random();

    // 生成随机页码（分散在不同时间段）
    final maxPage = (_totalCount / pageSize).ceil();
    final randomPages = <int>{};

    // 确保从不同时间段获取
    for (int i = 0; i < 5; i++) {
      randomPages.add(random.nextInt(maxPage));
    }

    // 从每个随机页加载
    for (final pageNum in randomPages) {
      try {
        final assets = await _allPhotos!.getAssetListPaged(
          page: pageNum,
          size: pageSize ~/ 5,
        );

        for (final asset in assets) {
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
      } catch (e) {
        debugPrint('加载页 $pageNum 失败: $e');
      }
    }

    // 打乱顺序
    photos.shuffle(_random);

    debugPrint('随机加载了 ${photos.length} 张照片');
    return photos;
  }

  /// 重置随机状态
  void resetRandom() {
    _usedIndices.clear();
  }

  /// 获取收藏的照片
  Future<List<PhotoRecord>> getFavorites() async {
    // TODO: 从本地数据库获取收藏的照片
    return [];
  }

  /// 删除照片
  Future<void> deletePhoto(String id) async {
    await PhotoManager.editor.deleteWithIds([id]);
  }

  /// 打开应用设置
  static Future<void> openSettings() async {
    await PhotoManager.openSetting();
  }
}
