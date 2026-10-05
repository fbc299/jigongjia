class AppConstants {
  AppConstants._();

  static const String dbName = 'jigongjia.db';
  static const int dbVersion = 1;

  /// 账号数据库文件名：未登录（空/无）沿用旧库名，登录后各账号独立数据库文件。
  static String dbFileNameForAccount(String? account) =>
      account == null || account.isEmpty ? dbName : 'jigongjia_$account.db';

  // Table names
  static const String tableProjects = 'projects';
  static const String tableWorkRecords = 'work_records';
  static const String tableBorrowRecords = 'borrow_records';
  static const String tableSettlements = 'settlements';
  static const String tablePhotoEvidence = 'photo_evidence';
  static const String tableExpenses = 'expenses';
  static const String tableNotes = 'notes';
}
