import 'package:photo_manager/photo_manager.dart';

class PhotoAsset {
  final String id;
  final String uri;
  final String? filename;
  final DateTime? creationTime;
  final int width;
  final int height;
  final AssetEntity? entity; // 保存 AssetEntity 用于加载图片

  PhotoAsset({
    required this.id,
    required this.uri,
    this.filename,
    this.creationTime,
    this.width = 0,
    this.height = 0,
    this.entity,
  });

  String get formattedTime {
    if (creationTime == null) return '未知时间';
    return '${creationTime!.year}-${creationTime!.month.toString().padLeft(2, '0')}-${creationTime!.day.toString().padLeft(2, '0')} '
        '${creationTime!.hour.toString().padLeft(2, '0')}:${creationTime!.minute.toString().padLeft(2, '0')}';
  }
}
