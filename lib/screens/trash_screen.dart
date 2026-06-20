import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/photo_record.dart';
import '../services/trash_service.dart';
import '../services/stats_service.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  final TrashService _trashService = TrashService();
  final StatsService _statsService = StatsService();
  List<PhotoRecord> _trashPhotos = [];
  bool _loading = true;
  bool _multiSelectMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    await _trashService.init();
    await _statsService.init();
    // 清理过期照片（30天）
    final freed = await _trashService.cleanupExpiredPhotos();
    if (freed > 0) {
      await _statsService.addFreedSpace(freed);
    }
    _loadTrashPhotos();
  }

  void _loadTrashPhotos() {
    setState(() {
      _trashPhotos = _trashService.getTrashPhotos();
      _loading = false;
    });
  }

  void _toggleSelect(String photoId) {
    setState(() {
      if (_selectedIds.contains(photoId)) {
        _selectedIds.remove(photoId);
        if (_selectedIds.isEmpty) {
          _multiSelectMode = false;
        }
      } else {
        _selectedIds.add(photoId);
      }
    });
  }

  void _enterMultiSelect(String photoId) {
    setState(() {
      _multiSelectMode = true;
      _selectedIds.add(photoId);
    });
  }

  void _exitMultiSelect() {
    setState(() {
      _multiSelectMode = false;
      _selectedIds.clear();
    });
  }

  void _selectAll() {
    setState(() {
      _selectedIds.addAll(_trashPhotos.map((p) => p.id));
    });
  }

  Future<void> _restoreSelected() async {
    int successCount = 0;
    int failCount = 0;

    for (final id in _selectedIds) {
      final success = await _trashService.restorePhoto(id);
      if (success) {
        successCount++;
      } else {
        failCount++;
      }
    }

    _exitMultiSelect();
    _loadTrashPhotos();

    if (!mounted) return;
    if (failCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('恢复完成：$successCount 成功，$failCount 失败'),
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已恢复 $successCount 张照片')),
      );
    }
  }

  Future<void> _restorePhoto(PhotoRecord photo) async {
    final success = await _trashService.restorePhoto(photo.id);
    _loadTrashPhotos();

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已恢复到相册')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('恢复失败，备份文件可能已丢失'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _deleteSelected() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('永久删除备份', style: TextStyle(color: Colors.white)),
        content: Text(
          '确定要永久删除选中的 ${_selectedIds.length} 张照片备份吗？此操作不可撤销。',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              int totalFreed = 0;
              for (final id in _selectedIds) {
                final freed = await _trashService.permanentlyDelete(id);
                if (freed > 0) totalFreed += freed;
              }
              if (totalFreed > 0) {
                await _statsService.addFreedSpace(totalFreed);
              }
              _exitMultiSelect();
              _loadTrashPhotos();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已永久删除，释放 ${_formatBytes(totalFreed)}')),
                );
              }
            },
            child: const Text('永久删除', style: TextStyle(color: Color(0xFFE24B4A))),
          ),
        ],
      ),
    );
  }

  void _permanentDelete(PhotoRecord photo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('永久删除备份', style: TextStyle(color: Colors.white)),
        content: const Text(
          '确定要永久删除这张照片的备份吗？此操作不可撤销。',
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
              final freed = await _trashService.permanentlyDelete(photo.id);
              if (freed > 0) {
                await _statsService.addFreedSpace(freed);
              }
              _loadTrashPhotos();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已永久删除，释放 ${_formatBytes(freed)}')),
                );
              }
            },
            child: const Text('永久删除', style: TextStyle(color: Color(0xFFE24B4A))),
          ),
        ],
      ),
    );
  }

  void _clearAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('清空暂删区', style: TextStyle(color: Colors.white)),
        content: Text(
          '确定要永久删除所有 ${_trashPhotos.length} 张照片备份吗？此操作不可撤销。',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final freed = await _trashService.clearTrash();
              if (freed > 0) {
                await _statsService.addFreedSpace(freed);
              }
              _loadTrashPhotos();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('暂删区已清空，释放 ${_formatBytes(freed)}')),
                );
              }
            },
            child: const Text('清空', style: TextStyle(color: Color(0xFFE24B4A))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: _multiSelectMode
            ? IconButton(
                onPressed: _exitMultiSelect,
                icon: const Icon(Icons.close, color: Colors.white),
              )
            : IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
        title: Row(
          children: [
            Text(
              _multiSelectMode ? '已选择 ${_selectedIds.length}' : '暂删区',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            if (!_multiSelectMode && _trashPhotos.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE24B4A).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_trashPhotos.length}',
                  style: const TextStyle(
                    color: Color(0xFFE24B4A),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_multiSelectMode) ...[
            TextButton(
              onPressed: _selectAll,
              child: const Text('全选', style: TextStyle(color: Color(0xFF7F77DD))),
            ),
          ] else if (_trashPhotos.isNotEmpty) ...[
            TextButton(
              onPressed: _clearAll,
              child: const Text('清空', style: TextStyle(color: Color(0xFFE24B4A))),
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF7F77DD)),
            )
          : _trashPhotos.isEmpty
              ? _buildEmptyState()
              : _buildPhotoGrid(),
      bottomNavigationBar: _multiSelectMode ? _buildBottomBar() : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.delete_outline, size: 56, color: Colors.grey[700]),
          ),
          const SizedBox(height: 24),
          const Text(
            '暂删区为空',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '删除的照片记录会在这里保留30天',
            style: TextStyle(color: Colors.grey[500], fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return Column(
      children: [
        // 提示信息
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.grey[500], size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '照片将在30天后自动永久删除',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
              ),
            ],
          ),
        ),

        // 九宫格照片流
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(2),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            itemCount: _trashPhotos.length,
            itemBuilder: (context, index) {
              final photo = _trashPhotos[index];
              return _buildGridItem(photo);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGridItem(PhotoRecord photo) {
    final isSelected = _selectedIds.contains(photo.id);
    final isRestorable = _trashService.isRestorable(photo.id);

    return GestureDetector(
      onTap: () {
        if (_multiSelectMode) {
          _toggleSelect(photo.id);
        } else {
          // 查看大图
          _showPhotoPreview(photo);
        }
      },
      onLongPress: () {
        if (!_multiSelectMode) {
          _enterMultiSelect(photo.id);
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 缩略图
          _buildThumbnail(photo),

          // 不可恢复标记
          if (!isRestorable)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning, color: Colors.orange, size: 24),
                    SizedBox(height: 4),
                    Text(
                      '备份缺失',
                      style: TextStyle(color: Colors.orange, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),

          // 选中状态边框
          if (isSelected)
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFF7F77DD),
                  width: 3,
                ),
              ),
            ),

          // 选中勾选图标
          if (isSelected)
            const Positioned(
              top: 4,
              right: 4,
              child: CircleAvatar(
                radius: 12,
                backgroundColor: Color(0xFF7F77DD),
                child: Icon(Icons.check, color: Colors.white, size: 16),
              ),
            ),

          // 文件大小
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
              child: Text(
                photo.formattedSize,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPhotoPreview(PhotoRecord photo) {
    final isRestorable = _trashService.isRestorable(photo.id);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            // 照片
            Center(
              child: _buildThumbnail(photo, fullSize: true),
            ),

            // 不可恢复提示
            if (!isRestorable)
              Positioned(
                top: MediaQuery.of(context).padding.top + 50,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '备份缺失，无法恢复',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),

            // 底部操作栏
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      icon: Icons.restore,
                      label: isRestorable ? '恢复到相册' : '不可恢复',
                      color: isRestorable ? const Color(0xFF639922) : Colors.grey,
                      onTap: isRestorable
                          ? () {
                              Navigator.pop(context);
                              _restorePhoto(photo);
                            }
                          : null,
                    ),
                    _buildActionButton(
                      icon: Icons.delete_forever,
                      label: '永久删除备份',
                      color: const Color(0xFFE24B4A),
                      onTap: () {
                        Navigator.pop(context);
                        _permanentDelete(photo);
                      },
                    ),
                  ],
                ),
              ),
            ),

            // 关闭按钮
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap != null ? 1.0 : 0.5,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withOpacity(0.2),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(
          top: BorderSide(color: Colors.grey[800]!),
        ),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildBottomButton(
              icon: Icons.restore,
              label: '恢复选中',
              color: const Color(0xFF639922),
              onTap: _selectedIds.isNotEmpty ? _restoreSelected : null,
            ),
            _buildBottomButton(
              icon: Icons.delete_forever,
              label: '永久删除',
              color: const Color(0xFFE24B4A),
              onTap: _selectedIds.isNotEmpty ? _deleteSelected : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap != null ? 1.0 : 0.5,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(PhotoRecord photo, {bool fullSize = false}) {
    // 先尝试从保存的文件路径获取缩略图
    final savedPath = _trashService.getTrashPhotoPath(photo.id);
    if (savedPath != null) {
      final file = File(savedPath);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: fullSize ? BoxFit.contain : BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholder();
          },
        );
      }
    }

    // 如果没有保存的路径，尝试从系统相册获取
    return FutureBuilder<File?>(
      future: _getFileFromSystem(photo.id),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return Image.file(
            snapshot.data!,
            fit: fullSize ? BoxFit.contain : BoxFit.cover,
          );
        }
        return _buildPlaceholder();
      },
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[800],
      child: const Center(
        child: Icon(Icons.image, color: Colors.grey, size: 24),
      ),
    );
  }

  Future<File?> _getFileFromSystem(String photoId) async {
    try {
      final asset = await AssetEntity.fromId(photoId);
      return await asset?.file;
    } catch (e) {
      return null;
    }
  }
}
