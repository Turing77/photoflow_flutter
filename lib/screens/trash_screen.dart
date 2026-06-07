import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/photo_record.dart';
import '../services/trash_service.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  final TrashService _trashService = TrashService();
  List<PhotoRecord> _trashPhotos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    await _trashService.init();
    _loadTrashPhotos();
  }

  void _loadTrashPhotos() {
    setState(() {
      _trashPhotos = _trashService.getTrashPhotos();
      _loading = false;
    });
  }

  void _restorePhoto(PhotoRecord photo) {
    _trashService.removeFromTrash(photo.id);
    _loadTrashPhotos();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('已恢复'),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () {
            _trashService.addToTrash(photo);
            _loadTrashPhotos();
          },
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.grey[900],
      ),
    );
  }

  void _permanentDelete(PhotoRecord photo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('永久删除', style: TextStyle(color: Colors.white)),
        content: const Text(
          '确定要永久删除这张照片吗？此操作不可撤销。',
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
              _trashService.removeFromTrash(photo.id);
              _loadTrashPhotos();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已永久删除')),
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
        title: const Text('清空废纸篓', style: TextStyle(color: Colors.white)),
        content: Text(
          '确定要永久删除所有 ${_trashPhotos.length} 张照片吗？此操作不可撤销。',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _trashService.clearTrash();
              _loadTrashPhotos();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('废纸篓已清空')),
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
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: Row(
          children: [
            const Text(
              '废纸篓',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            if (_trashPhotos.isNotEmpty) ...[
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
          if (_trashPhotos.isNotEmpty)
            TextButton(
              onPressed: _clearAll,
              child: const Text(
                '清空',
                style: TextStyle(color: Color(0xFFE24B4A)),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF7F77DD)),
            )
          : _trashPhotos.isEmpty
              ? _buildEmptyState()
              : _buildPhotoList(),
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
            '废纸篓为空',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '删除的照片会在这里保留30天',
            style: TextStyle(color: Colors.grey[500], fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoList() {
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

        // 照片列表
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _trashPhotos.length,
            itemBuilder: (context, index) {
              final photo = _trashPhotos[index];
              return _buildPhotoItem(photo);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoItem(PhotoRecord photo) {
    return Dismissible(
      key: Key(photo.id),
      direction: DismissDirection.horizontal,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF639922),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.restore, color: Colors.white),
            SizedBox(width: 8),
            Text('恢复', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE24B4A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('永久删除', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            SizedBox(width: 8),
            Icon(Icons.delete_forever, color: Colors.white),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          _restorePhoto(photo);
          return false;
        } else {
          _permanentDelete(photo);
          return false;
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(8),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 56,
              height: 56,
              child: _buildThumbnail(photo),
            ),
          ),
          title: Text(
            photo.filename ?? '未命名照片',
            style: const TextStyle(color: Colors.white, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${photo.formattedTime} · ${photo.formattedSize}',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          trailing: PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.grey[600]),
            color: const Color(0xFF1C1C1E),
            onSelected: (value) {
              if (value == 'restore') {
                _restorePhoto(photo);
              } else if (value == 'delete') {
                _permanentDelete(photo);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'restore',
                child: Row(
                  children: [
                    Icon(Icons.restore, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('恢复', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Color(0xFFE24B4A), size: 20),
                    SizedBox(width: 8),
                    Text('永久删除', style: TextStyle(color: Color(0xFFE24B4A))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(PhotoRecord photo) {
    // 尝试从系统相册获取缩略图
    return FutureBuilder<File?>(
      future: _getFileFromSystem(photo.id),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return Image.file(
            snapshot.data!,
            fit: BoxFit.cover,
          );
        }
        return Container(
          color: Colors.grey[800],
          child: const Center(
            child: Icon(Icons.image, color: Colors.grey, size: 24),
          ),
        );
      },
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
