import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:path_provider/path_provider.dart';
import '../models/photo_record.dart';
import '../services/photo_service.dart';
import '../services/stats_service.dart';
import '../services/favorites_service.dart';
import '../services/trash_service.dart';
import 'photo_viewer_screen.dart';
import 'delete_confirmation_screen.dart';

class ImageFlowScreen extends StatefulWidget {
  const ImageFlowScreen({super.key});

  @override
  State<ImageFlowScreen> createState() => ImageFlowScreenState();
}

class ImageFlowScreenState extends State<ImageFlowScreen>
    with TickerProviderStateMixin {
  final PhotoService _photoService = PhotoService();
  final StatsService _statsService = StatsService();
  final FavoritesService _favoritesService = FavoritesService();
  final TrashService _trashService = TrashService();
  final List<PhotoRecord> _photos = [];
  final List<PhotoRecord> _pendingDelete = [];

  int _currentIndex = 0;
  bool _loading = false;
  bool _hasMore = true;
  int _page = 0;
  String? _error;

  // 批次确认相关
  int _viewedCount = 0;
  static const int _batchSize = 50;
  bool _batchConfirmVisible = false;

  // 动画相关
  late AnimationController _slideController;
  late AnimationController _verticalSlideController;
  double _dragOffset = 0;
  double _verticalDragOffset = 0;
  bool _isDragging = false;
  bool _isVerticalDragging = false;

  // 文件缓存
  final Map<String, File?> _fileCache = {};

  // 放大模式
  bool _isZoomMode = false;

  @override
  void initState() {
    super.initState();
    _statsService.init();
    _favoritesService.init();
    _trashService.init();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _verticalSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadPhotos();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _verticalSlideController.dispose();
    super.dispose();
  }

  Future<void> _loadPhotos() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final photos = await _photoService.loadPhotos(page: _page);
      if (photos.isNotEmpty) {
        setState(() {
          _photos.addAll(photos);
          _hasMore = photos.length >= 50;
          _page++;
        });
        // 预加载当前和下一张的文件
        _preloadFiles();
      } else {
        setState(() => _hasMore = false);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  void _preloadFiles() {
    for (int i = _currentIndex; i < _currentIndex + 3 && i < _photos.length; i++) {
      _loadFile(_photos[i]);
    }
  }

  Future<void> _loadFile(PhotoRecord photo) async {
    if (_fileCache.containsKey(photo.id)) return;
    if (photo.entity == null) return;

    try {
      final file = await photo.entity!.file;
      if (mounted) {
        setState(() {
          _fileCache[photo.id] = file;
        });
      }
    } catch (e) {
      _fileCache[photo.id] = null;
    }
  }

  File? _getFile(PhotoRecord photo) {
    return _fileCache[photo.id];
  }

  PhotoRecord? get _currentPhoto =>
      _currentIndex < _photos.length ? _photos[_currentIndex] : null;

  PhotoRecord? get _nextPhoto =>
      _currentIndex + 1 < _photos.length ? _photos[_currentIndex + 1] : null;

  PhotoRecord? get _prevPhoto =>
      _currentIndex > 0 ? _photos[_currentIndex - 1] : null;

  // 上滑 - 删除
  void _onSwipeUp() {
    if (_currentPhoto == null) return;
    setState(() {
      _pendingDelete.add(_currentPhoto!);
      _currentPhoto!.status = PhotoStatus.deleted;
      _currentIndex++;
    });
    _statsService.incrementViewed();
    _viewedCount++;
    _checkBatchConfirmation();
    _showAutoToast('已标记删除', isDelete: true);
    _checkPreload();
  }

  // 下滑 - 收藏
  void _onSwipeDown() {
    if (_currentPhoto == null) return;
    final photo = _currentPhoto!;
    setState(() {
      photo.status = PhotoStatus.favorited;
      _currentIndex++;
    });
    // 保存到收藏服务
    _favoritesService.addFavorite(photo);
    _statsService.incrementFavorited();
    _statsService.incrementViewed();
    _viewedCount++;
    _checkBatchConfirmation();
    _showAutoToast('已收藏', isDelete: false);
    _checkPreload();
  }

  // 向左滑 - 下一张
  void _goToNext() {
    if (_currentIndex < _photos.length - 1) {
      setState(() {
        _currentIndex++;
        _statsService.incrementViewed();
        _viewedCount++;
      });
      _checkBatchConfirmation();
      _checkPreload();
    }
  }

  // 检查是否需要批次确认
  void _checkBatchConfirmation() {
    if (_viewedCount >= _batchSize && !_batchConfirmVisible) {
      _batchConfirmVisible = true;
      _showBatchConfirmDialog();
    }
  }

  // 显示批次确认对话框
  void _showBatchConfirmDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('批次确认', style: TextStyle(color: Colors.white)),
        content: Text(
          '你已浏览 $_viewedCount 张照片。\n'
          '待删除: ${_pendingDelete.length} 张\n'
          '是否继续下一批？',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              _batchConfirmVisible = false;
              _viewedCount = 0;
              // 处理待删除照片
              if (_pendingDelete.isNotEmpty) {
                await _deleteAllPending();
              }
            },
            child: const Text('删除并继续'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _batchConfirmVisible = false;
              _viewedCount = 0;
            },
            child: const Text('继续浏览'),
          ),
        ],
      ),
    );
  }

  // 向右滑 - 上一张
  void _goToPrev() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
    }
  }

  void _onTap() {
    if (_currentPhoto == null) return;
    setState(() {
      _isZoomMode = !_isZoomMode;
    });
  }

  void _exitZoomMode() {
    setState(() {
      _isZoomMode = false;
    });
  }

  void _checkPreload() {
    _preloadFiles();
    if (_currentIndex >= _photos.length - 3 && _hasMore && !_loading) {
      _loadPhotos();
    }
  }

  void _showAutoToast(String message, {required bool isDelete}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isDelete ? Icons.delete_outline : Icons.favorite_outline,
              color: isDelete ? const Color(0xFFE24B4A) : const Color(0xFF639922),
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(message, style: const TextStyle(fontSize: 14)),
          ],
        ),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.grey[900]?.withOpacity(0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        margin: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    );
  }

  Future<void> _showDeleteConfirmation() async {
    await showDeleteConfirmation();
  }

  Future<void> _deleteAllPending() async {
    if (_pendingDelete.isEmpty) return;

    // 容量检查
    if (!await _trashService.canBackupBatch(_pendingDelete)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('可用空间不足，无法备份照片'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // 准备阶段：备份原图 + 写入 prepared 记录
    final List<PhotoRecord> prepared = [];
    final List<PhotoRecord> prepareFailed = [];

    for (final photo in _pendingDelete) {
      try {
        final tempPath = await _trashService.prepareBackup(photo);
        if (tempPath != null) {
          final thumbPath = await _trashService.generateThumbnail(photo);
          await _trashService.writePreparedRecord(
            photo,
            tempBackupPath: tempPath,
            thumbnailPath: thumbPath,
          );
          prepared.add(photo);
        } else {
          prepareFailed.add(photo);
        }
      } catch (e) {
        debugPrint('准备备份失败: $e');
        prepareFailed.add(photo);
      }
    }

    // 系统删除阶段
    final List<PhotoRecord> committed = [];
    final List<PhotoRecord> deleteFailed = [];

    if (prepared.isNotEmpty) {
      final ids = prepared
          .where((p) => p.entity != null)
          .map((p) => p.entity!.id)
          .toList();

      if (ids.isNotEmpty) {
        try {
          final deletedIds = await PhotoManager.editor.deleteWithIds(ids);
          final deletedIdSet = Set<String>.from(deletedIds);

          for (final photo in prepared) {
            if (deletedIdSet.contains(photo.id)) {
              // 系统删除成功，提交记录
              final success = await _trashService.commitTrashRecord(photo.id);
              if (success) {
                committed.add(photo);
                _statsService.incrementDeleted();
              } else {
                // 提交失败，但原图已删除，记录仍在 prepared 状态
                // 启动扫描会处理这种情况
                committed.add(photo);
                _statsService.incrementDeleted();
              }
            } else {
              // 系统删除失败，回滚备份
              await _trashService.rollbackBackup(photo.id);
              deleteFailed.add(photo);
            }
          }
        } catch (e) {
          // 异常时，保持 prepared 状态，不增加统计，不从待删除列表移除
          debugPrint('系统删除异常（保持 prepared 状态）: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('删除结果待确认，请稍后重试'),
                duration: Duration(seconds: 3),
              ),
            );
          }
          // 不要 return，继续执行后续逻辑
        }
      }
    }

    // 更新待删除列表：只移除成功的项
    setState(() {
      for (final photo in committed) {
        _pendingDelete.remove(photo);
      }
    });

    // 提示结果
    if (mounted) {
      final messages = <String>[];
      if (prepareFailed.isNotEmpty) {
        messages.add('${prepareFailed.length} 张备份失败');
      }
      if (deleteFailed.isNotEmpty) {
        messages.add('${deleteFailed.length} 张删除失败');
      }
      if (messages.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(messages.join('，')),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // 公开属性：是否有待删除照片
  bool get hasPendingDelete => _pendingDelete.isNotEmpty;

  // 公开方法：显示删除确认（返回是否确认删除）
  Future<bool> showDeleteConfirmation() async {
    if (_pendingDelete.isEmpty) return true;

    try {
      final confirmed = await Navigator.push<bool>(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              DeleteConfirmationScreen(photos: _pendingDelete),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final tween = Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeOutCubic));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );

      if (confirmed == true) {
        await _deleteAllPending();
        return true;
      } else {
        setState(() {
          for (final photo in _pendingDelete) {
            photo.status = PhotoStatus.pending;
          }
          _pendingDelete.clear();
        });
        return false;
      }
    } catch (e) {
      debugPrint('删除确认流程异常: $e');
      // 异常时重置状态
      setState(() {
        for (final photo in _pendingDelete) {
          photo.status = PhotoStatus.pending;
        }
        _pendingDelete.clear();
      });
      return false;
    }
  }

  Future<void> _onPopInvokedWithResult(bool didPop, dynamic result) async {
    if (didPop) return;
    if (_pendingDelete.isNotEmpty) {
      final confirmed = await showDeleteConfirmation();
      if (confirmed && mounted) {
        Navigator.of(context).pop();
      }
    } else {
      Navigator.of(context).pop();
    }
  }

  // 处理水平拖拽
  void _onHorizontalDragStart(DragStartDetails details) {
    _isDragging = true;
    _dragOffset = 0;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    setState(() {
      _dragOffset += details.delta.dx;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;

    final velocity = details.velocity.pixelsPerSecond.dx;
    final screenWidth = MediaQuery.of(context).size.width;

    // 向左滑（负值）= 下一张
    if (_dragOffset < -screenWidth * 0.2 || velocity < -500) {
      _animateToNext();
    }
    // 向右滑（正值）= 上一张
    else if (_dragOffset > screenWidth * 0.2 || velocity > 500) {
      _animateToPrev();
    }
    // 回弹
    else {
      _animateBack();
    }
  }

  void _animateToNext() {
    if (_currentIndex >= _photos.length - 1) {
      _animateBack();
      return;
    }

    final screenWidth = MediaQuery.of(context).size.width;

    _slideController.reset();
    _slideController.duration = const Duration(milliseconds: 250);

    // 动画：当前图片向左移出，同时更新索引
    final animation = Tween<double>(
      begin: _dragOffset,
      end: -screenWidth,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    animation.addListener(() {
      setState(() {
        _dragOffset = animation.value;
      });
    });

    _slideController.forward().then((_) {
      if (!mounted) return;
      setState(() {
        _currentIndex++;
        _dragOffset = 0;
        _statsService.incrementViewed();
        _viewedCount++;
      });
      _checkBatchConfirmation();
      _checkPreload();
    });
  }

  void _animateToPrev() {
    if (_currentIndex <= 0) {
      _animateBack();
      return;
    }

    final screenWidth = MediaQuery.of(context).size.width;

    _slideController.reset();
    _slideController.duration = const Duration(milliseconds: 250);

    final animation = Tween<double>(
      begin: _dragOffset,
      end: screenWidth,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    animation.addListener(() {
      setState(() {
        _dragOffset = animation.value;
      });
    });

    _slideController.forward().then((_) {
      setState(() {
        _currentIndex--;
        _dragOffset = 0;
      });
    });
  }

  void _animateBack() {
    _slideController.reset();
    _slideController.duration = const Duration(milliseconds: 200);

    final animation = Tween<double>(
      begin: _dragOffset,
      end: 0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    animation.addListener(() {
      setState(() {
        _dragOffset = animation.value;
      });
    });

    _slideController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return _buildContent();
  }

  Widget _buildContent() {
    if (_loading && _photos.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF7F77DD)),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() => _error = null);
                _loadPhotos();
              },
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_photos.isEmpty || _currentIndex >= _photos.length) {
      return _buildEmptyState();
    }

    return _buildPhotoSlider();
  }

  Widget _buildPhotoSlider() {
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onPanStart: _isZoomMode ? null : _onVerticalDragStart,
      onPanUpdate: _isZoomMode ? null : _onVerticalDragUpdate,
      onPanEnd: _isZoomMode ? null : _onVerticalDragEnd,
      onTap: _isZoomMode ? _exitZoomMode : _onTap,
      child: Stack(
        children: [
          // 使用自定义裁剪实现平移效果
          _buildSlidingPhotos(screenWidth),

          // 顶部进度条（放大模式时隐藏）
          if (!_isZoomMode)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: _buildTopBar(),
            ),

          // 底部信息（放大模式时隐藏）
          if (!_isZoomMode)
            Positioned(
              bottom: 40,
              left: 16,
              right: 16,
              child: _buildBottomInfo(),
            ),

          // 放大模式覆盖层
          if (_isZoomMode) _buildZoomOverlay(),
        ],
      ),
    );
  }

  Widget _buildZoomOverlay() {
    final file = _currentPhoto != null ? _getFile(_currentPhoto!) : null;

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // 可缩放的图片 - 全屏显示
          Positioned.fill(
            child: file != null
                ? InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 5.0,
                    boundaryMargin: const EdgeInsets.all(double.infinity),
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height,
                      child: Image.file(
                        file,
                        fit: BoxFit.contain,
                        cacheWidth: 1920,
                      ),
                    ),
                  )
                : const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF7F77DD),
                    ),
                  ),
          ),

          // 顶部关闭按钮
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              onPressed: _exitZoomMode,
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

          // 底部提示
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '双指缩放 · 点击关闭',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 垂直手势处理（上下滑动）
  void _onVerticalDragStart(DragStartDetails details) {
    _isVerticalDragging = true;
    _verticalDragOffset = 0;
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (!_isVerticalDragging) return;
    setState(() {
      _verticalDragOffset += details.delta.dy;
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (!_isVerticalDragging) return;
    _isVerticalDragging = false;

    final velocity = details.velocity.pixelsPerSecond.dy;
    final screenHeight = MediaQuery.of(context).size.height;

    // 上滑删除
    if (_verticalDragOffset < -screenHeight * 0.15 || velocity < -500) {
      _animateVerticalSwipe(isUp: true);
    }
    // 下滑收藏
    else if (_verticalDragOffset > screenHeight * 0.15 || velocity > 500) {
      _animateVerticalSwipe(isUp: false);
    } else {
      // 回弹动画
      _verticalSlideController.reverse();
      setState(() {
        _verticalDragOffset = 0;
      });
    }
  }

  // 垂直滑动动画
  void _animateVerticalSwipe({required bool isUp}) {
    final screenHeight = MediaQuery.of(context).size.height;
    final startOffset = _verticalDragOffset;
    final endOffset = isUp ? -screenHeight : screenHeight;

    // 创建动画
    final animation = Tween<double>(
      begin: startOffset,
      end: endOffset,
    ).animate(CurvedAnimation(
      parent: _verticalSlideController,
      curve: Curves.easeOut,
    ));

    // 监听动画更新
    void listener() {
      setState(() {
        _verticalDragOffset = animation.value;
      });
    }

    animation.addListener(listener);

    _verticalSlideController.forward().then((_) {
      animation.removeListener(listener);
      if (!mounted) return;
      if (isUp) {
        _onSwipeUp();
      } else {
        _onSwipeDown();
      }
      _verticalSlideController.reset();
      setState(() {
        _verticalDragOffset = 0;
      });
    });
  }

  Widget _buildSlidingPhotos(double screenWidth) {
    final currentPhoto = _currentPhoto;
    final nextPhoto = _nextPhoto;
    final prevPhoto = _prevPhoto;

    return GestureDetector(
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: ClipRect(
        child: Stack(
          children: [
            // 上一张（右边，准备从左边进入）
            if (prevPhoto != null && _dragOffset > 0)
              Positioned(
                left: -screenWidth + _dragOffset,
                top: 0,
                bottom: 0,
                width: screenWidth,
                child: _buildPhotoWidget(prevPhoto),
              ),

            // 当前图片
            Positioned(
              left: _dragOffset,
              top: _verticalDragOffset,
              right: -_dragOffset,
              bottom: -_verticalDragOffset,
              child: _buildCurrentPhotoWithOverlay(currentPhoto),
            ),

            // 下一张（左边，准备从右边进入）
            if (nextPhoto != null && _dragOffset < 0)
              Positioned(
                left: screenWidth + _dragOffset,
                top: 0,
                bottom: 0,
                width: screenWidth,
                child: _buildPhotoWidget(nextPhoto),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPhotoWithOverlay(PhotoRecord? photo) {
    if (photo == null) return const SizedBox();

    final dy = _verticalDragOffset;
    final dx = _dragOffset;

    return Stack(
      fit: StackFit.expand,
      children: [
        _buildPhotoWidget(photo),

        // 上滑删除蒙层
        if (dy < -20)
          Container(
            color: Color.fromRGBO(200, 40, 40, ((dy.abs() - 20) / 200).clamp(0.0, 0.15)),
          ),

        // 下滑收藏蒙层
        if (dy > 20)
          Container(
            color: Color.fromRGBO(40, 180, 100, ((dy.abs() - 20) / 200).clamp(0.0, 0.15)),
          ),

        // 删除徽标
        if (dy < -50)
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE24B4A).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_outline, color: Colors.white, size: 24),
                    SizedBox(width: 10),
                    Text('删除', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),

        // 收藏徽标
        if (dy > 50)
          Positioned(
            bottom: 120,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF639922).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.favorite_outline, color: Colors.white, size: 24),
                    SizedBox(width: 10),
                    Text('收藏', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPhotoWidget(PhotoRecord photo) {
    final file = _getFile(photo);

    if (file == null) {
      return Container(
        color: Colors.grey[900],
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF7F77DD),
            strokeWidth: 2,
          ),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          Center(
            child: Image.file(
              file,
              fit: BoxFit.contain,
              cacheWidth: 1080,
            ),
          ),
          // 视频标识
          if (photo.isVideo)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.play_circle_outline, color: Colors.white, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        _formatDuration(photo.duration),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: _photos.isEmpty ? 0 : (_currentIndex + 1) / _photos.length,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF7F77DD)),
              minHeight: 3,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${_currentIndex + 1}/${_photos.length}',
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomInfo() {
    if (_currentPhoto == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _currentPhoto!.formattedTime,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            shadows: [Shadow(blurRadius: 10, color: Colors.black87)],
          ),
        ),
        if (_currentPhoto!.location != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on, size: 16, color: Colors.white70),
              const SizedBox(width: 4),
              Text(
                _currentPhoto!.location!.placeName,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ],
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
              gradient: const LinearGradient(colors: [Color(0xFF7F77DD), Color(0xFF6366F1)]),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 48, color: Colors.white),
          ),
          const SizedBox(height: 24),
          const Text('全部整理完毕！', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('你已浏览完所有照片', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
          if (_pendingDelete.isNotEmpty) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showDeleteConfirmation,
              icon: const Icon(Icons.delete_outline),
              label: Text('处理 ${_pendingDelete.length} 张待删除照片'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE24B4A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _photos.clear();
                _currentIndex = 0;
                _page = 0;
                _fileCache.clear();
              });
              _loadPhotos();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('重新加载'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7F77DD),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}
