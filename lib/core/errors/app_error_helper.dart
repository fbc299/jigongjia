import 'dart:io';

/// User-friendly error message extraction for the app.
class AppErrorHelper {
  AppErrorHelper._();

  /// Convert raw exception to user-friendly Chinese message.
  static String friendlyMessage(Object error) {
    final msg = error.toString();

    // Database errors
    if (msg.contains('UNIQUE constraint') || msg.contains('unique constraint')) {
      return '数据重复，请检查后重试';
    }
    if (msg.contains('FOREIGN KEY constraint') || msg.contains('foreign key constraint')) {
      return '关联数据不存在，请先创建相关记录';
    }
    if (msg.contains('database') || msg.contains('Database') || msg.contains('sqflite')) {
      return '数据库操作失败，请稍后重试';
    }

    // File/IO errors
    if (error is FileSystemException) {
      return '文件操作失败，请检查存储权限';
    }
    if (msg.contains('No space left') || msg.contains('disk full')) {
      return '存储空间不足，请清理后重试';
    }

    // Network errors
    if (msg.contains('SocketException') || msg.contains('Connection refused')) {
      return '网络连接失败，请检查网络设置';
    }
    if (msg.contains('TimeoutException') || msg.contains('timeout')) {
      return '操作超时，请稍后重试';
    }

    // Permission errors
    if (msg.contains('permission') || msg.contains('Permission')) {
      return '权限不足，请在设置中授权';
    }

    // Fallback
    return '操作失败，请稍后重试';
  }
}
