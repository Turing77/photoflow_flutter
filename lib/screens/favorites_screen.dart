import 'dart:io';
import 'package:flutter/material.dart';
import '../models/photo_record.dart';
import '../services/favorites_service.dart';
import 'photo_viewer_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => FavoritesScreenState();
}

class FavoritesScreenState extends State<FavoritesScreen> {
  final FavoritesService _favoritesService = FavoritesService();
  List<PhotoRecord> _favorites = [];
  bool _loading = true;
  String _selectedFilter = '全部';

  // 分组数据
  Map<String, List<PhotoRecord>> _groupedPhotos = {};

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 每次页面显示时刷新数据
    _loadFavorites();
  }

  Future<void> _initAndLoad() async {
    await _favoritesService.init();
    await _loadFavorites();
  }

  // 公开方法，供外部调用刷新
  void refresh() {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _loading = true);
    try {
      final favorites = await _favoritesService.getFavorites();
      setState(() {
        _favorites = favorites;
        _groupPhotos();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _groupPhotos() {
    _groupedPhotos.clear();

    if (_selectedFilter == '时间') {
      for (final photo in _favorites) {
        final key = '${photo.createdAt.year}年${photo.createdAt.month}月';
        _groupedPhotos.putIfAbsent(key, () => []).add(photo);
      }
    } else if (_selectedFilter == '地点') {
      for (final photo in _favorites) {
        final key = photo.location?.placeName ?? '未知地点';
        _groupedPhotos.putIfAbsent(key, () => []).add(photo);
      }
    } else {
      for (final photo in _favorites) {
        final key = '${photo.createdAt.month}月${photo.createdAt.day}日';
        _groupedPhotos.putIfAbsent(key, () => []).add(photo);
      }
    }
  }

  void _removeFavorite(PhotoRecord photo) async {
    await _favoritesService.removeFavorite(photo.id);
    _loadFavorites();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('已取消收藏'),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () async {
              await _favoritesService.addFavorite(photo);
              _loadFavorites();
            },
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.grey[900],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Row(
          children: [
            const Text(
              '收藏夹',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            if (_favorites.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF7F77DD).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_favorites.length}',
                  style: const TextStyle(
                    color: Color(0xFF7F77DD),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadFavorites,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterTabs(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF7F77DD)),
                  )
                : _favorites.isEmpty
                    ? _buildEmptyState()
                    : _selectedFilter == '全部'
                        ? _buildPhotoGrid()
                        : _buildGroupedList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    final filters = ['全部', '时间', '地点'];
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (_) {
                setState(() {
                  _selectedFilter = filter;
                  _groupPhotos();
                });
              },
              selectedColor: const Color(0xFF7F77DD),
              backgroundColor: Colors.grey[900],
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[400],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: _favorites.length,
      itemBuilder: (context, index) {
        final photo = _favorites[index];
        return _buildPhotoItem(photo, index, _favorites);
      },
    );
  }

  Widget _buildGroupedList() {
    final groups = _groupedPhotos.entries.toList();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return _buildGroupSection(group.key, group.value);
      },
    );
  }

  Widget _buildGroupSection(String title, List<PhotoRecord> photos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${photos.length}张',
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: photos.length,
            itemBuilder: (context, index) {
              return _buildHorizontalPhotoItem(photos[index], index, photos);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalPhotoItem(PhotoRecord photo, int index, List<PhotoRecord> groupPhotos) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PhotoViewerScreen(
              photos: groupPhotos,
              initialIndex: index,
            ),
          ),
        );
      },
      onLongPress: () => _showRemoveDialog(photo),
      child: Container(
        width: 120,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _buildImage(photo),
        ),
      ),
    );
  }

  Widget _buildPhotoItem(PhotoRecord photo, int index, List<PhotoRecord> photos) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PhotoViewerScreen(
              photos: photos,
              initialIndex: index,
            ),
          ),
        );
      },
      onLongPress: () => _showRemoveDialog(photo),
      child: _buildImage(photo),
    );
  }

  Widget _buildImage(PhotoRecord photo) {
    return FutureBuilder<File?>(
      future: photo.entity?.file,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return Image.file(
            snapshot.data!,
            fit: BoxFit.cover,
          );
        }
        return Container(
          color: Colors.grey[900],
          child: const Center(
            child: Icon(Icons.image, color: Colors.grey),
          ),
        );
      },
    );
  }

  void _showRemoveDialog(PhotoRecord photo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('取消收藏', style: TextStyle(color: Colors.white)),
        content: const Text(
          '确定要将这张照片从收藏中移除吗？',
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
              _removeFavorite(photo);
            },
            child: const Text('移除', style: TextStyle(color: Color(0xFFE24B4A))),
          ),
        ],
      ),
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
            child: Icon(Icons.favorite_outline, size: 56, color: Colors.grey[700]),
          ),
          const SizedBox(height: 24),
          const Text(
            '暂无收藏',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              '在整理页面下滑即可收藏照片\n收藏的照片会显示在这里',
              style: TextStyle(color: Colors.grey[500], fontSize: 15),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
