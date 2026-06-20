import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'favorites_screen.dart';
import 'image_flow_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 1; // 默认在"整理"页

  // 用于通知收藏页面刷新的Key
  final GlobalKey<FavoritesScreenState> _favoritesKey = GlobalKey();

  // ImageFlowScreen 的 Global Key，用于调用删除确认
  final GlobalKey<ImageFlowScreenState> _imageFlowKey = GlobalKey();

  // StatsScreen 的 Global Key，用于刷新数据
  final GlobalKey<StatsScreenState> _statsKey = GlobalKey();

  void _onTabChanged(int index) {
    // 切换到收藏页面时刷新数据
    if (index == 0 && _favoritesKey.currentState != null) {
      _favoritesKey.currentState!.refresh();
    }
    // 切换到统计页面时刷新数据
    if (index == 2 && _statsKey.currentState != null) {
      _statsKey.currentState!.refresh();
    }
    setState(() => _currentIndex = index);
  }

  Future<void> _onPopInvokedWithResult(bool didPop, dynamic result) async {
    if (didPop) return;
    // 如果在整理页面且有待删除照片，显示确认弹窗
    if (_currentIndex == 1 && _imageFlowKey.currentState != null) {
      final hasPendingDelete = _imageFlowKey.currentState!.hasPendingDelete;
      if (hasPendingDelete) {
        final confirmed = await _imageFlowKey.currentState!.showDeleteConfirmation();
        // 确认完成后留在整理页，不 pop 根路由
        return;
      }
    }
    // 没有待删除照片时，使用平台退出
    if (mounted) {
      // 使用 SystemNavigator.pop() 退出应用
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onPopInvokedWithResult,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            FavoritesScreen(key: _favoritesKey),
            ImageFlowScreen(key: _imageFlowKey),
            StatsScreen(key: _statsKey),
            const SettingsScreen(),
          ],
        ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.favorite_outline, Icons.favorite, '收藏'),
                _buildNavItem(1, Icons.style_outlined, Icons.style, '整理'),
                _buildNavItem(2, Icons.bar_chart_outlined, Icons.bar_chart, '统计'),
                _buildNavItem(3, Icons.settings_outlined, Icons.settings, '设置'),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? const Color(0xFF7F77DD) : Colors.grey[600];

    return GestureDetector(
      onTap: () => _onTabChanged(index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
