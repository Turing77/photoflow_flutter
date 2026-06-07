import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/photo_asset.dart';

class PhotoCard extends StatelessWidget {
  final PhotoAsset photo;
  final bool showFooter;
  final bool isFavorite;

  const PhotoCard({
    super.key,
    required this.photo,
    this.showFooter = false,
    this.isFavorite = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final cardWidth = screenWidth - 24;
    final cardHeight = (screenHeight * 0.78).clamp(0.0, 760.0);

    return Container(
      width: cardWidth,
      height: cardHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        color: const Color(0xFF1A2430),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 图片
          _buildImage(),

          // 底部信息栏
          if (showFooter)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 30, 20, 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.44),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        photo.formattedTime,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isFavorite)
                      const Text(
                        '★',
                        style: TextStyle(
                          color: Color(0xFFFFD36D),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    // 如果有 AssetEntity，使用 FutureBuilder 加载文件
    if (photo.entity != null) {
      return FutureBuilder<File?>(
        future: photo.entity!.file,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF9BE2B1),
                strokeWidth: 2,
              ),
            );
          }

          if (snapshot.hasError || snapshot.data == null) {
            debugPrint('加载图片失败: ${snapshot.error}');
            return _buildErrorWidget();
          }

          return Image.file(
            snapshot.data!,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('显示图片失败: $error');
              return _buildErrorWidget();
            },
          );
        },
      );
    }

    // 否则显示错误
    return _buildErrorWidget();
  }

  Widget _buildErrorWidget() {
    return Container(
      color: const Color(0xFF1A2430),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image,
              color: Color(0xFF475449),
              size: 48,
            ),
            SizedBox(height: 8),
            Text(
              '无法加载图片',
              style: TextStyle(
                color: Color(0xFF475449),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
