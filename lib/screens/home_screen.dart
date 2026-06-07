import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/photo_asset.dart';
import '../services/photo_service.dart';
import '../widgets/photo_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final PhotoService _photoService = PhotoService();
  final List<PhotoAsset> _photos = [];
  final List<PhotoAsset> _pendingDelete = [];
  final List<PhotoAsset> _favorites = [];
  final List<_HistoryEntry> _history = [];

  int _currentIndex = 0;
  bool _loading = false;
  bool _hasMore = true;
  int _page = 0;
  String? _error;

  // 动画控制器
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  // 手势状态
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  bool _isHorizontalDrag = false;
  bool _isVerticalDrag = false;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -1.5),
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    _loadPhotos();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadPhotos() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final photos = await _photoService.loadPhotos(page: _page);
      if (photos.isNotEmpty) {
        final shuffled = _photoService.shufflePhotos(photos);
        setState(() {
          _photos.addAll(shuffled);
          _hasMore = photos.length >= PhotoService.pageSize;
          _page++;
        });
      } else {
        setState(() {
          _hasMore = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  PhotoAsset? get _currentPhoto =>
      _currentIndex < _photos.length ? _photos[_currentIndex] : null;

  PhotoAsset? get _nextPhoto =>
      _currentIndex + 1 < _photos.length ? _photos[_currentIndex + 1] : null;

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
      _dragOffset = Offset.zero;
      _isHorizontalDrag = false;
      _isVerticalDrag = false;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta;

      if (!_isHorizontalDrag && !_isVerticalDrag) {
        if (_dragOffset.dx.abs() > 8 || _dragOffset.dy.abs() > 8) {
          if (_dragOffset.dx.abs() > _dragOffset.dy.abs()) {
            _isHorizontalDrag = true;
          } else {
            _isVerticalDrag = true;
          }
        }
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDragging) return;

    final velocity = details.velocity.pixelsPerSecond;
    final dx = _dragOffset.dx;
    final dy = _dragOffset.dy;

    // 垂直滑动 - 删除（上滑）
    if (_isVerticalDrag && dy < -100) {
      _deleteCurrent();
      return;
    }

    // 垂直滑动 - 收藏（下滑）
    if (_isVerticalDrag && dy > 100) {
      _favoriteCurrent();
      return;
    }

    // 水平滑动 - 下一张
    if (_isHorizontalDrag && (dx < -60 || velocity.dx < -200)) {
      _goToNext();
      return;
    }

    // 水平滑动 - 上一张
    if (_isHorizontalDrag && (dx > 60 || velocity.dx > 200)) {
      _goToPrevious();
      return;
    }

    _resetPosition();
  }

  void _resetPosition() {
    setState(() {
      _dragOffset = Offset.zero;
      _isDragging = false;
      _isHorizontalDrag = false;
      _isVerticalDrag = false;
    });
  }

  void _deleteCurrent() {
    final photo = _currentPhoto;
    if (photo == null) return;

    setState(() {
      _pendingDelete.add(photo);
      _history.add(_HistoryEntry(
        photo: photo,
        action: _Action.delete,
        index: _currentIndex,
        addedToPendingDelete: true,
      ));
      _dragOffset = Offset.zero;
      _isDragging = false;
    });

    _slideController.forward().then((_) {
      _slideController.reset();
      _goToNextIndex();
    });
  }

  void _favoriteCurrent() {
    final photo = _currentPhoto;
    if (photo == null) return;

    setState(() {
      if (!_favorites.contains(photo)) {
        _favorites.add(photo);
      }
      _history.add(_HistoryEntry(
        photo: photo,
        action: _Action.favorite,
        index: _currentIndex,
        addedToFavorite: true,
      ));
      _dragOffset = Offset.zero;
      _isDragging = false;
    });

    _goToNextIndex();
  }

  void _goToNext() {
    if (_currentPhoto == null) return;

    setState(() {
      _history.add(_HistoryEntry(
        photo: _currentPhoto!,
        action: _Action.next,
        index: _currentIndex,
      ));
      _dragOffset = Offset.zero;
      _isDragging = false;
    });

    _goToNextIndex();
  }

  void _goToPrevious() {
    if (_currentIndex <= 0) {
      _resetPosition();
      return;
    }

    setState(() {
      _currentIndex--;
      _dragOffset = Offset.zero;
      _isDragging = false;
    });
  }

  void _goToNextIndex() {
    setState(() {
      _currentIndex++;
    });

    if (_currentIndex >= _photos.length - 6 && _hasMore && !_loading) {
      _loadPhotos();
    }
  }

  void _undoLastAction() {
    if (_history.isEmpty) return;

    final entry = _history.removeLast();
    setState(() {
      _currentIndex = entry.index;
      if (entry.addedToPendingDelete) {
        _pendingDelete.remove(entry.photo);
      }
      if (entry.addedToFavorite) {
        _favorites.remove(entry.photo);
      }
    });
  }

  void _showDeletePreview() {
    if (_pendingDelete.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildDeletePreviewSheet(),
    );
  }

  Widget _buildDeletePreviewSheet() {
    return StatefulBuilder(
      builder: (context, setModalState) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 拖拽指示器
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 标题
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '待删除照片',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '共 ${_pendingDelete.length} 张照片',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
              // 照片网格
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _pendingDelete.length,
                  itemBuilder: (context, index) {
                    final photo = _pendingDelete[index];
                    return _buildPreviewCard(photo, setModalState);
                  },
                ),
              ),
              // 操作按钮
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  border: Border(
                    top: BorderSide(color: Colors.grey[800]!),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('返回'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[800],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _pendingDelete.isEmpty
                            ? null
                            : () async {
                                await _confirmDelete();
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                              },
                        icon: const Icon(Icons.delete_forever),
                        label: const Text('确认删除'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPreviewCard(PhotoAsset photo, StateSetter setModalState) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 图片
          FutureBuilder<File?>(
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
          ),
          // 删除按钮
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () {
                setModalState(() {
                  _pendingDelete.remove(photo);
                });
                setState(() {});
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete() async {
    if (_pendingDelete.isEmpty) return;

    final ids = _pendingDelete.map((p) => p.id).toList();
    await _photoService.deletePhotos(ids);

    setState(() {
      _pendingDelete.clear();
      _photos.clear();
      _currentIndex = 0;
      _page = 0;
      _history.clear();
    });

    await _loadPhotos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Logo 和标题
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.photo_library,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Photo Flow',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          // 统计信息
          if (_photos.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_currentIndex + 1}/${_photos.length}',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          const SizedBox(width: 8),
          // 操作按钮
          if (_pendingDelete.isNotEmpty)
            _buildActionButton(
              icon: Icons.delete_outline,
              count: _pendingDelete.length,
              color: Colors.red,
              onTap: _showDeletePreview,
            ),
          if (_history.isNotEmpty) ...[
            const SizedBox(width: 8),
            _buildActionButton(
              icon: Icons.undo,
              color: Colors.blue,
              onTap: _undoLastAction,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    int? count,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            if (count != null) ...[
              const SizedBox(width: 4),
              Text(
                '$count',
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading && _photos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                shape: BoxShape.circle,
              ),
              child: const CircularProgressIndicator(
                color: Color(0xFF667EEA),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '正在加载照片...',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_photos.isEmpty) {
      return _buildEmptyState();
    }

    if (_currentIndex >= _photos.length) {
      return _buildCompleteState();
    }

    return _buildPhotoStack();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.photo_library_outlined,
                size: 64,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              '欢迎使用 Photo Flow',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '授权访问相册，开始浏览和管理你的照片',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: _loadPhotos,
              icon: const Icon(Icons.refresh),
              label: const Text('授权并加载'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667EEA),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => PhotoManager.openSetting(),
              icon: Icon(Icons.settings, color: Colors.grey[500]),
              label: Text(
                '打开应用设置',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompleteState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                size: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              '浏览完成',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _pendingDelete.isNotEmpty
                  ? '${_pendingDelete.length} 张照片等待删除'
                  : '你已浏览完所有照片',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            if (_pendingDelete.isNotEmpty)
              ElevatedButton.icon(
                onPressed: _showDeletePreview,
                icon: const Icon(Icons.delete_outline),
                label: const Text('处理待删除照片'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _photos.clear();
                  _currentIndex = 0;
                  _page = 0;
                });
                _loadPhotos();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('重新加载'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[800],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoStack() {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 下一张卡片（背景）
          if (_nextPhoto != null)
            Transform.scale(
              scale: 0.95,
              child: Transform.translate(
                offset: const Offset(0, 8),
                child: Opacity(
                  opacity: 0.5,
                  child: PhotoCard(photo: _nextPhoto!),
                ),
              ),
            ),

          // 删除标记
          if (_isVerticalDrag && _dragOffset.dy < -30)
            Positioned(
              top: 40,
              child: AnimatedOpacity(
                opacity: ((_dragOffset.dy.abs() - 30) / 100).clamp(0.0, 1.0),
                duration: const Duration(milliseconds: 100),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete_outline, color: Colors.white, size: 24),
                      SizedBox(width: 8),
                      Text(
                        '删除',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 收藏标记
          if (_isVerticalDrag && _dragOffset.dy > 30)
            Positioned(
              bottom: 100,
              child: AnimatedOpacity(
                opacity: ((_dragOffset.dy.abs() - 30) / 100).clamp(0.0, 1.0),
                duration: const Duration(milliseconds: 100),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, color: Colors.white, size: 24),
                      SizedBox(width: 8),
                      Text(
                        '收藏',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 当前卡片
          if (_currentPhoto != null)
            Transform.translate(
              offset: _dragOffset,
              child: PhotoCard(
                photo: _currentPhoto!,
                showFooter: true,
                isFavorite: _favorites.contains(_currentPhoto),
              ),
            ),

          // 底部操作提示
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: _buildActionHints(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionHints() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildHintItem(
            icon: Icons.arrow_back,
            label: '上一张',
            color: Colors.grey[600]!,
          ),
          _buildHintItem(
            icon: Icons.arrow_upward,
            label: '删除',
            color: Colors.red[400]!,
          ),
          _buildHintItem(
            icon: Icons.arrow_downward,
            label: '收藏',
            color: Colors.amber[400]!,
          ),
          _buildHintItem(
            icon: Icons.arrow_forward,
            label: '下一张',
            color: Colors.grey[600]!,
          ),
        ],
      ),
    );
  }

  Widget _buildHintItem({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

enum _Action { delete, favorite, next }

class _HistoryEntry {
  final PhotoAsset photo;
  final _Action action;
  final int index;
  final bool addedToPendingDelete;
  final bool addedToFavorite;

  _HistoryEntry({
    required this.photo,
    required this.action,
    required this.index,
    this.addedToPendingDelete = false,
    this.addedToFavorite = false,
  });
}
