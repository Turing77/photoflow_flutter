import 'package:flutter/services.dart';

class StorageService {
  static const MethodChannel _channel = MethodChannel('com.example.photoflow_flutter/storage');

  /// 获取设备存储信息
  /// 返回 Map: {'total': bytes, 'free': bytes, 'used': bytes}
  static Future<Map<String, int>> getStorageInfo() async {
    try {
      final Map<dynamic, dynamic> result = await _channel.invokeMethod('getStorageInfo');
      return {
        'total': result['total'] ?? 0,
        'free': result['free'] ?? 0,
        'used': result['used'] ?? 0,
      };
    } catch (e) {
      return {'total': 0, 'free': 0, 'used': 0};
    }
  }

  /// 通过 media URI 获取文件大小
  static Future<int> getFileSize(String uri) async {
    try {
      final int result = await _channel.invokeMethod('getFileSize', {'uri': uri});
      return result;
    } catch (e) {
      return 0;
    }
  }

  /// 格式化字节数为可读字符串
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
