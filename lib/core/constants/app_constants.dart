class AppConstants {
  AppConstants._();

  static const String appName = '吉工家';
  static const String dbName = 'jigongjia.db';
  static const int dbVersion = 1;

  // Work type labels
  static const Map<String, String> workTypeLabels = {
    'point': '点工',
    'packageDay': '包工(按天)',
    'packageQty': '包工(按量)',
  };

  // Expense categories
  static const List<String> expenseCategories = [
    '餐饮',
    '交通',
    '住宿',
    '工具',
    '材料',
    '通讯',
    '医疗',
    '其他',
  ];

  // Quantity units
  static const List<String> qtyUnits = [
    '平方',
    '米',
    '立方',
    '件',
  ];

  // Settlement type labels
  static const Map<String, String> settlementTypeLabels = {
    'partial': '部分结算',
    'full': '全部结算',
  };

  // Date format patterns
  static const String dateFormatYMD = 'yyyy-MM-dd';
  static const String dateFormatYM = 'yyyy年MM月';
  static const String dateFormatFull = 'yyyy-MM-dd HH:mm:ss';
  static const String dateFormatChinese = 'yyyy年MM月dd日';
  static const String dateFormatMonthDay = 'MM月dd日';

  // Default rates
  static const double defaultDailyRate = 300.0;
  static const double defaultOvertimeRate = 50.0;
  static const double defaultPackageDayRate = 0.0;
  static const double defaultPackageQtyRate = 0.0;

  // Table names
  static const String tableProjects = 'projects';
  static const String tableWorkRecords = 'work_records';
  static const String tableBorrowRecords = 'borrow_records';
  static const String tableSettlements = 'settlements';
  static const String tablePhotoEvidence = 'photo_evidence';
  static const String tableExpenses = 'expenses';
  static const String tableNotes = 'notes';
}
