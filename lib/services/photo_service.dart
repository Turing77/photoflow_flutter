import 'dart:math';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/photo_record.dart';
import 'favorites_service.dart';
import 'storage_service.dart';

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
      type: RequestType.common,
      hasAll: true,
    );

    if (albums.isEmpty) return;

    _allPhotos = albums.first;

    // 获取实际总数
    _totalCount = await _allPhotos!.assetCountAsync;
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

  /// 加载随机照片和视频
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
            // 获取文件大小
            int fileSize = 0;
            try {
              final file = await asset.file;
              if (file != null) {
                fileSize = await file.length();
              }
            } catch (e) {
              debugPrint('获取文件大小失败 (file.length): $e');
            }

            // 如果 file.length() 失败，通过平台通道查询 MediaStore
            if (fileSize == 0) {
              try {
                fileSize = await StorageService.getFileSize(uri);
              } catch (e) {
                debugPrint('获取文件大小失败 (platform): $e');
              }
            }

            photos.add(PhotoRecord(
              id: asset.id,
              uri: uri,
              filename: asset.title,
              createdAt: asset.createDateTime,
              width: asset.width,
              height: asset.height,
              fileSize: fileSize,
              isVideo: asset.type == AssetType.video,
              duration: asset.duration,
              entity: asset,
            ));
          }
        }
      } catch (e) {
        debugPrint('加载页 $pageNum 失败: $e');
      }
    }

    // 额外加载一些视频以确保视频被包含
    final videoPhotos = await _loadVideos(5);
    photos.addAll(videoPhotos);

    // 打乱顺序
    photos.shuffle(_random);

    debugPrint('随机加载了 ${photos.length} 个媒体（包含 ${videoPhotos.length} 个视频）');
    return photos;
  }

  /// 加载视频
  Future<List<PhotoRecord>> _loadVideos(int count) async {
    final videos = <PhotoRecord>[];

    try {
      // 使用 common 类型获取所有相册（包含图片和视频）
      final allAlbums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        hasAll: true,
      );

      debugPrint('找到 ${allAlbums.length} 个相册');

      if (allAlbums.isEmpty) return [];

      // 遍历所有相册，查找包含视频的相册
      for (final album in allAlbums) {
        final name = album.name;
        final assetCount = await album.assetCountAsync;
        debugPrint('相册: $name, 数量: $assetCount');

        // 加载该相册的资源，筛选出视频
        final assets = await album.getAssetListPaged(
          page: 0,
          size: assetCount > 100 ? 100 : assetCount,
        );

        for (final asset in assets) {
          if (asset.type == AssetType.video) {
            final uri = await asset.getMediaUrl();
            if (uri != null) {
              int fileSize = 0;
              try {
                final file = await asset.file;
                if (file != null) {
                  fileSize = await file.length();
                }
              } catch (e) {
                debugPrint('获取视频文件大小失败: $e');
              }

              if (fileSize == 0) {
                try {
                  fileSize = await StorageService.getFileSize(uri);
                } catch (e) {
                  debugPrint('获取视频文件大小失败 (platform): $e');
                }
              }

              videos.add(PhotoRecord(
                id: asset.id,
                uri: uri,
                filename: asset.title,
                createdAt: asset.createDateTime,
                width: asset.width,
                height: asset.height,
                fileSize: fileSize,
                isVideo: true,
                duration: asset.duration,
                entity: asset,
              ));
            }
          }
        }

        // 如果已经找到足够的视频，停止搜索
        if (videos.length >= count) break;
      }
    } catch (e) {
      debugPrint('加载视频失败: $e');
    }

    debugPrint('找到 ${videos.length} 个视频');
    return videos.take(count).toList();
  }

  /// 重置随机状态
  void resetRandom() {
    _usedIndices.clear();
  }

  /// 获取收藏的照片
  Future<List<PhotoRecord>> getFavorites() async {
    final favoritesService = FavoritesService();
    await favoritesService.init();
    return await favoritesService.getFavorites();
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
