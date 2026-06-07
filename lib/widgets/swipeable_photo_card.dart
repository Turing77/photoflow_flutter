import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../models/photo_record.dart';

class SwipeablePhotoCard extends StatefulWidget {
  final PhotoRecord photo;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;
  final VoidCallback? onSwipeUp;
  final VoidCallback? onSwipeDown;
  final VoidCallback? onTap;
  final bool showOverlay;

  const SwipeablePhotoCard({
    super.key,
    required this.photo,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.onSwipeUp,
    this.onSwipeDown,
    this.onTap,
    this.showOverlay = true,
  });

  @override
  State<SwipeablePhotoCard> createState() => _SwipeablePhotoCardState();
}

class _SwipeablePhotoCardState extends State<SwipeablePhotoCard> {
  Offset _dragOffset = Offset.zero;
  File? _cachedFile;
  bool _isLoading = true;

  // 阈值
  static const double _horizontalThreshold = 0.3;
  static const double _verticalThreshold = 0.2;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  @override
  void didUpdateWidget(SwipeablePhotoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo.id != widget.photo.id) {
      _loadFile();
    }
  }

  Future<void> _loadFile() async {
    if (widget.photo.entity == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final file = await widget.photo.entity!.file;
      if (mounted) {
        setState(() {
          _cachedFile = file;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onTap: widget.onTap,
      child: Transform.translate(
        offset: _dragOffset,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 照片
            _buildPhoto(),

            // 蒙层和徽标
            if (widget.showOverlay) ..._buildOverlays(),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoto() {
    if (_isLoading) {
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

    if (_cachedFile == null) {
      return Container(
        color: Colors.grey[900],
        child: const Center(
          child: Icon(Icons.broken_image, color: Colors.grey, size: 48),
        ),
      );
    }

    // 使用 BoxFit.contain 保持图片比例，完整显示
    return Container(
      color: Colors.black,
      child: Center(
        child: Image.file(
          _cachedFile!,
          fit: BoxFit.contain, // 改为 contain，保持比例
          cacheWidth: 1080, // 缓存优化，减少内存
        ),
      ),
    );
  }

  List<Widget> _buildOverlays() {
    final size = MediaQuery.of(context).size;
    final dx = _dragOffset.dx;
    final widgets = <Widget>[];

    if (dx < -10) {
      // 左滑 - 删除
      final opacity = (dx.abs() / (size.width * _horizontalThreshold)).clamp(0.0, 1.0);
      widgets.addAll([
        Container(
          color: Color.fromRGBO(200, 40, 40, opacity * 0.12),
        ),
        if (dx < -30)
          Positioned(
            left: 20,
            top: 0,
            bottom: 0,
            child: Center(
              child: Opacity(
                opacity: opacity,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE24B4A).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete_outline, color: Colors.white, size: 20),
                      SizedBox(width: 6),
                      Text('删除', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ]);
    } else if (dx > 10) {
      // 右滑 - 收藏
      final opacity = (dx.abs() / (size.width * _horizontalThreshold)).clamp(0.0, 1.0);
      widgets.addAll([
        Container(
          color: Color.fromRGBO(40, 180, 100, opacity * 0.12),
        ),
        if (dx > 30)
          Positioned(
            right: 20,
            top: 0,
            bottom: 0,
            child: Center(
              child: Opacity(
                opacity: opacity,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF639922).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite_outline, color: Colors.white, size: 20),
                      SizedBox(width: 6),
                      Text('收藏', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ]);
    }

    return widgets;
  }

  void _onPanStart(DragStartDetails details) {
    setState(() => _dragOffset = Offset.zero);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() => _dragOffset += details.delta);
  }

  void _onPanEnd(DragEndDetails details) {
    final size = MediaQuery.of(context).size;
    final dx = _dragOffset.dx;
    final dy = _dragOffset.dy;

    // 左滑删除
    if (dx < -size.width * _horizontalThreshold) {
      widget.onSwipeLeft?.call();
      return;
    }

    // 右滑收藏
    if (dx > size.width * _horizontalThreshold) {
      widget.onSwipeRight?.call();
      return;
    }

    // 上滑下一张
    if (dy < -size.height * _verticalThreshold) {
      widget.onSwipeUp?.call();
      return;
    }

    // 下滑上一张
    if (dy > size.height * _verticalThreshold) {
      widget.onSwipeDown?.call();
      return;
    }

    // 回弹
    setState(() => _dragOffset = Offset.zero);
  }
}
