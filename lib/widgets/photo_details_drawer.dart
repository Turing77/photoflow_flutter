import 'package:flutter/material.dart';
import '../models/photo_record.dart';

class PhotoDetailsDrawer extends StatelessWidget {
  final PhotoRecord photo;

  const PhotoDetailsDrawer({
    super.key,
    required this.photo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
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
                    color: const Color(0xFF7F77DD).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.info_outline,
                    color: Color(0xFF7F77DD),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  '照片详情',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // 详情列表
          Flexible(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shrinkWrap: true,
              children: [
                _buildSection(
                  '基本信息',
                  [
                    _buildDetailRow(
                      Icons.access_time,
                      '拍摄时间',
                      photo.formattedTime,
                    ),
                    _buildDetailRow(
                      Icons.image_outlined,
                      '分辨率',
                      photo.resolution,
                    ),
                    _buildDetailRow(
                      Icons.storage_outlined,
                      '文件大小',
                      photo.formattedSize,
                    ),
                    if (photo.filename != null)
                      _buildDetailRow(
                        Icons.text_fields,
                        '文件名',
                        photo.filename!,
                      ),
                  ],
                ),
                if (photo.location != null) ...[
                  const SizedBox(height: 16),
                  _buildSection(
                    '位置信息',
                    [
                      _buildDetailRow(
                        Icons.location_on_outlined,
                        '拍摄地点',
                        photo.location!.placeName,
                      ),
                      _buildDetailRow(
                        Icons.map_outlined,
                        '坐标',
                        '${photo.location!.latitude.toStringAsFixed(6)}, ${photo.location!.longitude.toStringAsFixed(6)}',
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                _buildSection(
                  '设备信息',
                  [
                    _buildDetailRow(
                      Icons.phone_android,
                      '设备',
                      '未知设备', // TODO: 从 EXIF 获取
                    ),
                    _buildDetailRow(
                      Icons.camera_outlined,
                      '光圈',
                      'f/1.8', // TODO: 从 EXIF 获取
                    ),
                    _buildDetailRow(
                      Icons.timer_outlined,
                      '快门',
                      '1/125s', // TODO: 从 EXIF 获取
                    ),
                    _buildDetailRow(
                      Icons.iso_outlined,
                      'ISO',
                      '100', // TODO: 从 EXIF 获取
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[850],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[500], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static void show(BuildContext context, PhotoRecord photo) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => PhotoDetailsDrawer(photo: photo),
    );
  }
}
