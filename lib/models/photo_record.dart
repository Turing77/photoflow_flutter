import 'package:photo_manager/photo_manager.dart';

/// 照片状态
enum PhotoStatus {
  pending,   // 待处理
  kept,      // 保留/跳过
  deleted,   // 已删除
  favorited; // 已收藏
}

/// 照片位置信息
class PhotoLocation {
  final double latitude;
  final double longitude;
  final String placeName;

  const PhotoLocation({
    required this.latitude,
    required this.longitude,
    this.placeName = '',
  });
}

/// 照片记录
class PhotoRecord {
  final String id;
  final String uri;
  final String? filename;
  final DateTime createdAt;
  DateTime? lastViewedAt;
  PhotoStatus status;
  final PhotoLocation? location;
  final int fileSize;
  final int width;
  final int height;
  final AssetEntity? entity;

  PhotoRecord({
    required this.id,
    required this.uri,
    this.filename,
    required this.createdAt,
    this.lastViewedAt,
    this.status = PhotoStatus.pending,
    this.location,
    this.fileSize = 0,
    this.width = 0,
    this.height = 0,
    this.entity,
  });

  /// 格式化拍摄时间
  String get formattedTime {
    return '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')} '
        '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
  }

  /// 格式化文件大小
  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    if (fileSize < 1024 * 1024 * 1024) return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// 格式化分辨率
  String get resolution => '$width × $height';
}
