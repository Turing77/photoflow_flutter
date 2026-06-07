import 'package:shared_preferences/shared_preferences.dart';

/// 统计数据服务
class StatsService {
  static const String _keyViewedCount = 'viewed_count';
  static const String _keyFavoritedCount = 'favorited_count';
  static const String _keyDeletedCount = 'deleted_count';
  static const String _keyFreedSpace = 'freed_space';
  static const String _keyStreakDays = 'streak_days';
  static const String _keyLastActiveDate = 'last_active_date';
  static const String _keyDailyViewed = 'daily_viewed';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _checkStreak();
  }

  // 查看计数
  int get viewedCount => _prefs.getInt(_keyViewedCount) ?? 0;
  Future<void> incrementViewed() async {
    await _prefs.setInt(_keyViewedCount, viewedCount + 1);
    await _incrementDailyViewed();
  }

  // 收藏计数
  int get favoritedCount => _prefs.getInt(_keyFavoritedCount) ?? 0;
  Future<void> incrementFavorited() async {
    await _prefs.setInt(_keyFavoritedCount, favoritedCount + 1);
  }

  // 删除计数
  int get deletedCount => _prefs.getInt(_keyDeletedCount) ?? 0;
  Future<void> incrementDeleted() async {
    await _prefs.setInt(_keyDeletedCount, deletedCount + 1);
  }

  // 释放空间
  int get freedSpace => _prefs.getInt(_keyFreedSpace) ?? 0;
  Future<void> addFreedSpace(int bytes) async {
    await _prefs.setInt(_keyFreedSpace, freedSpace + bytes);
  }

  // 连续天数
  int get streakDays => _prefs.getInt(_keyStreakDays) ?? 0;

  // 检查连续天数
  Future<void> _checkStreak() async {
    final lastActive = _prefs.getString(_keyLastActiveDate);
    final now = DateTime.now();
    final today = '${now.year}-${now.month}-${now.day}';

    if (lastActive == null) {
      await _prefs.setInt(_keyStreakDays, 1);
      await _prefs.setString(_keyLastActiveDate, today);
      return;
    }

    if (lastActive == today) return;

    final lastDate = DateTime.parse(lastActive);
    final difference = now.difference(lastDate).inDays;

    if (difference == 1) {
      await _prefs.setInt(_keyStreakDays, streakDays + 1);
    } else if (difference > 1) {
      await _prefs.setInt(_keyStreakDays, 1);
    }

    await _prefs.setString(_keyLastActiveDate, today);
  }

  // 每日查看数量
  Future<void> _incrementDailyViewed() async {
    final now = DateTime.now();
    final key = 'daily_${now.year}_${now.month}_${now.day}';
    final count = _prefs.getInt(key) ?? 0;
    await _prefs.setInt(key, count + 1);
  }

  // 获取最近7天的数据
  List<int> getWeeklyData() {
    final now = DateTime.now();
    final data = <int>[];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key = 'daily_${date.year}_${date.month}_${date.day}';
      data.add(_prefs.getInt(key) ?? 0);
    }

    return data;
  }

  // 格式化释放空间
  String get formattedFreedSpace {
    final bytes = freedSpace;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // 重置统计数据
  Future<void> resetStats() async {
    await _prefs.remove(_keyViewedCount);
    await _prefs.remove(_keyFavoritedCount);
    await _prefs.remove(_keyDeletedCount);
    await _prefs.remove(_keyFreedSpace);
  }
}
