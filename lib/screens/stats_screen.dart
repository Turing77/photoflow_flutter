import 'package:flutter/material.dart';
import '../services/stats_service.dart';
import 'trash_screen.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final StatsService _statsService = StatsService();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initStats();
  }

  Future<void> _initStats() async {
    await _statsService.init();
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF7F77DD)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          '整理统计',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMetricsGrid(),
            const SizedBox(height: 20),
            _buildProgressBar(),
            const SizedBox(height: 20),
            _buildStreakSection(),
            const SizedBox(height: 20),
            _buildDailyChart(),
            const SizedBox(height: 20),
            _buildActionDistribution(),
            const SizedBox(height: 20),
            _buildStorageSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _buildMetricCard(
          '已查看',
          '${_statsService.viewedCount}',
          const Color(0xFF7F77DD),
          Icons.visibility_outlined,
        ),
        _buildMetricCard(
          '已收藏',
          '${_statsService.favoritedCount}',
          const Color(0xFF639922),
          Icons.favorite_outline,
        ),
        _buildMetricCard(
          '已删除',
          '${_statsService.deletedCount}',
          const Color(0xFFE24B4A),
          Icons.delete_outline,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TrashScreen()),
            );
          },
        ),
        _buildMetricCard(
          '已释放',
          _statsService.formattedFreedSpace,
          Colors.orange,
          Icons.storage_outlined,
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, Color color, IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
                if (onTap != null) ...[
                  const Spacer(),
                  Icon(Icons.chevron_right, color: Colors.grey[600], size: 16),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 32,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final total = _statsService.viewedCount;
    final processed = _statsService.favoritedCount + _statsService.deletedCount;
    final progress = total > 0 ? processed / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '整理进度',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  color: Color(0xFF7F77DD),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[800],
              valueColor: const AlwaysStoppedAnimation(Color(0xFF7F77DD)),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '已处理 $processed / $total 张',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakSection() {
    final streak = _statsService.streakDays;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF7F77DD).withOpacity(0.3),
            Colors.grey[900]!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF7F77DD).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.local_fire_department, color: Colors.orange, size: 36),
              const SizedBox(width: 12),
              Text(
                '$streak',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '天',
                    style: TextStyle(color: Colors.grey[400], fontSize: 18),
                  ),
                  const Text(
                    '连续整理',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildStreakDots(streak),
          const SizedBox(height: 8),
          Text(
            '每天整理照片，保持连续记录',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakDots(int streak) {
    final now = DateTime.now();
    final weekday = now.weekday;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(7, (index) {
        final dayIndex = (index + 1);
        final isCompleted = dayIndex <= streak && dayIndex <= weekday;
        final isToday = dayIndex == weekday;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            children: [
              Text(
                ['一', '二', '三', '四', '五', '六', '日'][index],
                style: TextStyle(
                  color: isToday ? const Color(0xFF7F77DD) : Colors.grey[600],
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted
                      ? const Color(0xFF7F77DD)
                      : Colors.transparent,
                  border: isToday
                      ? Border.all(color: const Color(0xFF7F77DD), width: 2)
                      : Border.all(color: Colors.grey[800]!, width: 1),
                ),
                child: isCompleted
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : isToday
                        ? const Icon(Icons.access_time, color: Color(0xFF7F77DD), size: 14)
                        : null,
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildDailyChart() {
    final data = _statsService.getWeeklyData();
    final maxCount = data.isEmpty ? 1 : data.reduce((a, b) => a > b ? a : b);
    final days = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final now = DateTime.now();
    final currentWeekday = now.weekday;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '每日整理数量',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(7, (index) {
            final dayIndex = (index + 1);
            final isToday = dayIndex == currentWeekday;
            final count = data[index];

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      days[index],
                      style: TextStyle(
                        color: isToday ? const Color(0xFF7F77DD) : Colors.grey[600],
                        fontSize: 12,
                        fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: maxCount > 0 ? count / maxCount : 0,
                        backgroundColor: Colors.grey[800],
                        valueColor: AlwaysStoppedAnimation(
                          isToday
                              ? const Color(0xFF7F77DD)
                              : const Color(0xFF7F77DD).withOpacity(0.6),
                        ),
                        minHeight: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 32,
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: isToday ? const Color(0xFF7F77DD) : Colors.white,
                        fontSize: 13,
                        fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActionDistribution() {
    final total = _statsService.viewedCount;
    if (total == 0) return const SizedBox();

    final kept = total - _statsService.favoritedCount - _statsService.deletedCount;
    final favorited = _statsService.favoritedCount;
    final deleted = _statsService.deletedCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '操作分布',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildDistributionRow('保留/跳过', kept, total, Colors.grey),
          const SizedBox(height: 8),
          _buildDistributionRow('收藏', favorited, total, const Color(0xFF639922)),
          const SizedBox(height: 8),
          _buildDistributionRow('删除', deleted, total, const Color(0xFFE24B4A)),
        ],
      ),
    );
  }

  Widget _buildDistributionRow(String label, int count, int total, Color color) {
    final percentage = total > 0 ? (count / total * 100).toInt() : 0;

    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
        ),
        Text(
          '$count 张',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          child: Text(
            '$percentage%',
            style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w600),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildStorageSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '存储空间',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStorageItem(
                  '本月释放',
                  _statsService.formattedFreedSpace,
                  Colors.orange,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.grey[800],
              ),
              Expanded(
                child: _buildStorageItem(
                  '累计释放',
                  _statsService.formattedFreedSpace,
                  const Color(0xFF7F77DD),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStorageItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
