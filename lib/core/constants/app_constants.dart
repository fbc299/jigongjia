class AppConstants {
  AppConstants._();

  static const String dbName = 'jigongjia.db';

  /// 数据库版本历史
  /// v1: 初始结构
  /// v2: work_records 增加 UNIQUE(projectId, date) —— 同一项目一天只允许一条记工（S3）
  static const int dbVersion = 3;

  // Table names
  static const String tableProjects = 'projects';
  static const String tableWorkRecords = 'work_records';
  static const String tableBorrowRecords = 'borrow_records';
  static const String tableSettlements = 'settlements';
  static const String tablePhotoEvidence = 'photo_evidence';
  static const String tableExpenses = 'expenses';
  static const String tableNotes = 'notes';
}
