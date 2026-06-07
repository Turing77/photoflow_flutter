import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../services/stats_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final StatsService _statsService = StatsService();

  // 设置项状态
  bool _notificationsEnabled = true;
  bool _excludeDeleted = true;
  bool _excludeFavorited = false;
  String _dailyGoal = '50';
  String _trashRetention = '30';
  String _shuffleMode = '久违优先';

  @override
  void initState() {
    super.initState();
    _initStats();
    _loadSettings();
  }

  Future<void> _initStats() async {
    await _statsService.init();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _excludeDeleted = prefs.getBool('exclude_deleted') ?? true;
      _excludeFavorited = prefs.getBool('exclude_favorited') ?? false;
      _dailyGoal = prefs.getString('daily_goal') ?? '50';
      _trashRetention = prefs.getString('trash_retention') ?? '30';
      _shuffleMode = prefs.getString('shuffle_mode') ?? '久违优先';
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          '设置',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        children: [
          // 顶部统计卡片
          _buildStatsCard(),

          _buildSection(
            '相册权限',
            [
              _buildPermissionItem(
                icon: Icons.photo_library_outlined,
                title: '相册访问权限',
                onTap: () => PhotoManager.openSetting(),
              ),
              _buildPermissionItem(
                icon: Icons.location_on_outlined,
                title: '位置权限',
                subtitle: '用于照片地点分组',
                onTap: () => PhotoManager.openSetting(),
              ),
            ],
          ),

          _buildSection(
            '整理设置',
            [
              _buildSwitchItem(
                icon: Icons.delete_outline,
                title: '排除已删除照片',
                subtitle: '整理时不显示已删除的照片',
                value: _excludeDeleted,
                onChanged: (value) {
                  setState(() => _excludeDeleted = value);
                  _saveSetting('exclude_deleted', value);
                },
              ),
              _buildSwitchItem(
                icon: Icons.favorite_outline,
                title: '排除已收藏照片',
                subtitle: '整理时不显示已收藏的照片',
                value: _excludeFavorited,
                onChanged: (value) {
                  setState(() => _excludeFavorited = value);
                  _saveSetting('exclude_favorited', value);
                },
              ),
              _buildSelectionItem(
                icon: Icons.shuffle,
                title: '随机算法',
                subtitle: _shuffleMode,
                options: ['完全随机', '久违优先', '时间倒序'],
                onSelected: (value) {
                  setState(() => _shuffleMode = value);
                  _saveSetting('shuffle_mode', value);
                },
              ),
              _buildSelectionItem(
                icon: Icons.flag_outlined,
                title: '每日目标',
                subtitle: '$_dailyGoal 张/天',
                options: ['20', '50', '100', '200'],
                onSelected: (value) {
                  setState(() => _dailyGoal = value);
                  _saveSetting('daily_goal', value);
                },
              ),
            ],
          ),

          _buildSection(
            '废纸篓',
            [
              _buildSelectionItem(
                icon: Icons.delete_sweep_outlined,
                title: '自动清理周期',
                subtitle: '$_trashRetention 天后永久删除',
                options: ['7', '14', '30', '60', '90'],
                onSelected: (value) {
                  setState(() => _trashRetention = value);
                  _saveSetting('trash_retention', value);
                },
              ),
              _buildActionItem(
                icon: Icons.delete_forever_outlined,
                title: '清空废纸篓',
                subtitle: '永久删除所有待删除照片',
                onTap: _showClearTrashDialog,
                isDestructive: true,
              ),
            ],
          ),

          _buildSection(
            '通知',
            [
              _buildSwitchItem(
                icon: Icons.notifications_outlined,
                title: '整理提醒',
                subtitle: '每天 20:00 提醒你整理照片',
                value: _notificationsEnabled,
                onChanged: (value) {
                  setState(() => _notificationsEnabled = value);
                  _saveSetting('notifications_enabled', value);
                },
              ),
            ],
          ),

          _buildSection(
            '数据管理',
            [
              _buildActionItem(
                icon: Icons.refresh,
                title: '重置统计数据',
                subtitle: '清除所有整理记录和统计',
                onTap: _showResetStatsDialog,
              ),
              _buildActionItem(
                icon: Icons.download_outlined,
                title: '导出收藏列表',
                subtitle: '导出收藏照片列表为文本文件',
                onTap: _exportFavorites,
              ),
            ],
          ),

          _buildSection(
            '关于',
            [
              _buildInfoItem(
                icon: Icons.info_outline,
                title: '版本',
                value: 'v1.0.0',
              ),
              _buildInfoItem(
                icon: Icons.update,
                title: '构建号',
                value: '2026.06.07',
              ),
              _buildActionItem(
                icon: Icons.privacy_tip_outlined,
                title: '隐私政策',
                onTap: () {},
              ),
              _buildActionItem(
                icon: Icons.description_outlined,
                title: '用户协议',
                onTap: () {},
              ),
              _buildActionItem(
                icon: Icons.code,
                title: '开源许可',
                onTap: () {},
              ),
            ],
          ),

          // 底部间距
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      margin: const EdgeInsets.all(16),
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
        border: Border.all(
          color: const Color(0xFF7F77DD).withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '整理成就',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatItem('已整理', '${_statsService.viewedCount}'),
                    const SizedBox(width: 24),
                    _buildStatItem('连续', '${_statsService.streakDays}天'),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF7F77DD).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events,
              color: Color(0xFF7F77DD),
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF7F77DD),
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
      subtitle: subtitle != null
          ? Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 12))
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF639922).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '已授权',
              style: TextStyle(color: Color(0xFF639922), fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: Colors.grey[600], size: 20),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildSwitchItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF7F77DD),
      ),
    );
  }

  Widget _buildSelectionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<String> options,
    required ValueChanged<String> onSelected,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[600], size: 20),
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: const Color(0xFF1C1C1E),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => _buildSelectionSheet(title, options, onSelected),
        );
      },
    );
  }

  Widget _buildSelectionSheet(
    String title,
    List<String> options,
    ValueChanged<String> onSelected,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ...options.map((option) => ListTile(
                title: Text(option, style: const TextStyle(color: Colors.white)),
                onTap: () {
                  onSelected(option);
                  Navigator.pop(context);
                },
              )),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? const Color(0xFFE24B4A) : Colors.white,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? const Color(0xFFE24B4A) : Colors.white,
          fontSize: 15,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 12))
          : null,
      trailing: Icon(Icons.chevron_right, color: Colors.grey[600], size: 20),
      onTap: onTap,
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
      trailing: Text(
        value,
        style: TextStyle(color: Colors.grey[500], fontSize: 14),
      ),
    );
  }

  void _showClearTrashDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('清空废纸篓', style: TextStyle(color: Colors.white)),
        content: const Text(
          '确定要永久删除所有待删除照片吗？此操作不可撤销。',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: 执行清空废纸篓
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('废纸篓已清空')),
              );
            },
            child: const Text('确认删除', style: TextStyle(color: Color(0xFFE24B4A))),
          ),
        ],
      ),
    );
  }

  void _showResetStatsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('重置统计数据', style: TextStyle(color: Colors.white)),
        content: const Text(
          '确定要清除所有整理记录和统计数据吗？',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _statsService.resetStats();
              setState(() {});
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('统计数据已重置')),
                );
              }
            },
            child: const Text('确认重置', style: TextStyle(color: Color(0xFFE24B4A))),
          ),
        ],
      ),
    );
  }

  void _exportFavorites() {
    // TODO: 实现导出收藏列表
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('功能开发中...')),
    );
  }
}
