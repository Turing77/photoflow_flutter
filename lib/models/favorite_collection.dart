/// 收藏集类型
enum CollectionType {
  location, // 按地点
  person,   // 按人物
  time,     // 按时间
  custom;   // 自定义
}

/// 收藏集
class FavoriteCollection {
  final String id;
  final String name;
  final CollectionType type;
  final String? coverPhotoId;
  final List<String> photoIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FavoriteCollection({
    required this.id,
    required this.name,
    required this.type,
    this.coverPhotoId,
    this.photoIds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  int get photoCount => photoIds.length;
}
