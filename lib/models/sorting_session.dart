/// 整理会话
class SortingSession {
  final String id;
  final DateTime date;
  int viewedCount;
  int favoritedCount;
  int deletedCount;
  int freedSpace; // 字节
  int durationSeconds;

  SortingSession({
    required this.id,
    required this.date,
    this.viewedCount = 0,
    this.favoritedCount = 0,
    this.deletedCount = 0,
    this.freedSpace = 0,
    this.durationSeconds = 0,
  });

  /// 格式化释放空间
  String get formattedFreedSpace {
    if (freedSpace < 1024) return '$freedSpace B';
    if (freedSpace < 1024 * 1024) return '${(freedSpace / 1024).toStringAsFixed(1)} KB';
    if (freedSpace < 1024 * 1024 * 1024) return '${(freedSpace / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(freedSpace / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
