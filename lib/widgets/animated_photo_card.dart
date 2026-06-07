import 'dart:io';
import 'package:flutter/material.dart';
import '../models/photo_record.dart';

/// 动画方向
enum SlideDirection {
  up,
  down,
  left,
  right,
  none,
}

/// 带动画的照片卡片
class AnimatedPhotoCard extends StatefulWidget {
  final PhotoRecord photo;
  final VoidCallback? onSwipeUp;    // 上滑 - 删除
  final VoidCallback? onSwipeDown;  // 下滑 - 收藏
  final VoidCallback? onSwipeLeft;  // 左滑 - 下一张
  final VoidCallback? onSwipeRight; // 右滑 - 上一张
  final VoidCallback? onTap;
  final bool showOverlay;
  final bool showNextOnRight; // 是否在右边显示下一张

  const AnimatedPhotoCard({
    super.key,
    required this.photo,
    this.onSwipeUp,
    this.onSwipeDown,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.onTap,
    this.showOverlay = true,
    this.showNextOnRight = true,
  });

  @override
  State<AnimatedPhotoCard> createState() => _AnimatedPhotoCardState();
}

class _AnimatedPhotoCardState extends State<AnimatedPhotoCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _opacityAnimation;

  double _dragDx = 0;
  double _dragDy = 0;
  bool _isHorizontalDrag = false;
  bool _isVerticalDrag = false;
  bool _directionLocked = false;

  SlideDirection _direction = SlideDirection.none;
  File? _cachedFile;
  bool _isLoading = true;

  // 手势阈值
  static const double _horizontalThreshold = 0.25;
  static const double _verticalThreshold = 0.15;
  static const double _lockThreshold = 10.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
    _loadFile();
  }

  @override
  void didUpdateWidget(AnimatedPhotoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo.id != widget.photo.id) {
      _loadFile();
      _resetState();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _resetState() {
    _controller.reset();
    _dragDx = 0;
    _dragDy = 0;
    _isHorizontalDrag = false;
    _isVerticalDrag = false;
    _directionLocked = false;
    _direction = SlideDirection.none;
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

  void _animateOut(SlideDirection direction) {
    setState(() => _direction = direction);

    Offset endOffset;
    switch (direction) {
      case SlideDirection.up:
        endOffset = const Offset(0, -1.5);
        break;
      case SlideDirection.down:
        endOffset = const Offset(0, 1.5);
        break;
      case SlideDirection.left:
        endOffset = const Offset(-1.5, 0);
        break;
      case SlideDirection.right:
        endOffset = const Offset(1.5, 0);
        break;
      default:
        endOffset = Offset.zero;
    }

    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: endOffset,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.forward().then((_) {
      _controller.reset();
      _dragDx = 0;
      _dragDy = 0;
      _direction = SlideDirection.none;
      _directionLocked = false;

      switch (direction) {
        case SlideDirection.up:
          widget.onSwipeUp?.call();
          break;
        case SlideDirection.down:
          widget.onSwipeDown?.call();
          break;
        case SlideDirection.left:
          widget.onSwipeLeft?.call();
          break;
        case SlideDirection.right:
          widget.onSwipeRight?.call();
          break;
        default:
          break;
      }
    });
  }

  void _animateBack() {
    final currentOffset = Offset(_dragDx, _dragDy);
    _slideAnimation = Tween<Offset>(
      begin: currentOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.forward().then((_) {
      _controller.reset();
      setState(() {
        _dragDx = 0;
        _dragDy = 0;
        _direction = SlideDirection.none;
        _directionLocked = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        listenable: _controller,
        builder: (context, child) {
          final dx = _controller.isAnimating ? _slideAnimation.value.dx : _dragDx;
          final dy = _controller.isAnimating ? _slideAnimation.value.dy : _dragDy;

          return Transform.translate(
            offset: Offset(
              dx * MediaQuery.of(context).size.width,
              dy * MediaQuery.of(context).size.height,
            ),
            child: Opacity(
              opacity: _controller.isAnimating ? _opacityAnimation.value : 1.0,
              child: child,
            ),
          );
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildPhoto(),
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

    return Container(
      color: Colors.black,
      child: Center(
        child: Image.file(
          _cachedFile!,
          fit: BoxFit.contain,
          cacheWidth: 1080,
        ),
      ),
    );
  }

  List<Widget> _buildOverlays() {
    final dx = _dragDx;
    final dy = _dragDy;
    final widgets = <Widget>[];

    // 上滑 - 删除（红色蒙层 + 删除徽标）
    if (dy < -0.05 && _isVerticalDrag) {
      final progress = (dy.abs() / _verticalThreshold).clamp(0.0, 1.0);
      widgets.addAll([
        Container(
          color: Color.fromRGBO(200, 40, 40, progress * 0.15),
        ),
        Positioned(
          top: 40,
          left: 0,
          right: 0,
          child: Center(
            child: Opacity(
              opacity: progress,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE24B4A).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE24B4A).withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
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
        ),
      ]);
    }

    // 下滑 - 收藏（绿色蒙层 + 收藏徽标）
    if (dy > 0.05 && _isVerticalDrag) {
      final progress = (dy.abs() / _verticalThreshold).clamp(0.0, 1.0);
      widgets.addAll([
        Container(
          color: Color.fromRGBO(40, 180, 100, progress * 0.15),
        ),
        Positioned(
          bottom: 120,
          left: 0,
          right: 0,
          child: Center(
            child: Opacity(
              opacity: progress,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF639922).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF639922).withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
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
        ),
      ]);
    }

    return widgets;
  }

  void _onPanStart(DragStartDetails details) {
    if (_controller.isAnimating) return;
    setState(() {
      _dragDx = 0;
      _dragDy = 0;
      _isHorizontalDrag = false;
      _isVerticalDrag = false;
      _directionLocked = false;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_controller.isAnimating) return;

    final size = MediaQuery.of(context).size;
    final dx = details.delta.dx / size.width;
    final dy = details.delta.dy / size.height;

    setState(() {
      _dragDx += dx;
      _dragDy += dy;

      // 锁定方向
      if (!_directionLocked) {
        if (_dragDx.abs() > _lockThreshold / size.width ||
            _dragDy.abs() > _lockThreshold / size.height) {
          _directionLocked = true;
          if (_dragDx.abs() > _dragDy.abs()) {
            _isHorizontalDrag = true;
            _isVerticalDrag = false;
          } else {
            _isHorizontalDrag = false;
            _isVerticalDrag = true;
          }
        }
      }

      // 根据锁定的方向限制位移
      if (_isHorizontalDrag) {
        _dragDy = 0; // 水平拖拽时垂直归零
      } else if (_isVerticalDrag) {
        _dragDx = 0; // 垂直拖拽时水平归零
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_controller.isAnimating) return;

    final velocity = details.velocity.pixelsPerSecond;
    final dx = _dragDx;
    final dy = _dragDy;

    final velocityThresholdX = velocity.dx.abs() > 500;
    final velocityThresholdY = velocity.dy.abs() > 500;

    if (_isVerticalDrag) {
      // 上滑删除
      if (dy < -_verticalThreshold || (dy < -0.05 && velocityThresholdY && velocity.dy < 0)) {
        _animateOut(SlideDirection.up);
        return;
      }

      // 下滑收藏
      if (dy > _verticalThreshold || (dy > 0.05 && velocityThresholdY && velocity.dy > 0)) {
        _animateOut(SlideDirection.down);
        return;
      }
    }

    if (_isHorizontalDrag) {
      // 从左往右滑（dx > 0）= 下一张（向右飞出）
      if (dx > _horizontalThreshold || (dx > 0.05 && velocityThresholdX && velocity.dx > 0)) {
        _animateOut(SlideDirection.right);
        return;
      }

      // 从右往左滑（dx < 0）= 上一张（向左飞出）
      if (dx < -_horizontalThreshold || (dx < -0.05 && velocityThresholdX && velocity.dx < 0)) {
        _animateOut(SlideDirection.left);
        return;
      }
    }

    // 回弹
    _animateBack();
  }
}

class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required super.listenable,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}
