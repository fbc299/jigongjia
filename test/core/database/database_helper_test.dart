import 'package:flutter_test/flutter_test.dart';
import 'package:jigongjia/core/database/database_helper.dart';
import 'package:jigongjia/core/constants/app_constants.dart';

void main() {
  group('DatabaseHelper', () {
    test('should be a singleton', () {
      final instance1 = DatabaseHelper.instance;
      final instance2 = DatabaseHelper.instance;
      expect(identical(instance1, instance2), true);
    });

    test('should have correct database name constant', () {
      expect(AppConstants.dbName, 'jigongjia.db');
    });

    test('should have correct database version', () {
      expect(AppConstants.dbVersion, 1);
    });

    test('should define all required table names', () {
      expect(AppConstants.tableProjects, 'projects');
      expect(AppConstants.tableWorkRecords, 'work_records');
      expect(AppConstants.tableBorrowRecords, 'borrow_records');
      expect(AppConstants.tableSettlements, 'settlements');
      expect(AppConstants.tablePhotoEvidence, 'photo_evidence');
      expect(AppConstants.tableExpenses, 'expenses');
      expect(AppConstants.tableNotes, 'notes');
    });

    test('should have correct app name', () {
      expect(AppConstants.appName, '吉工家');
    });

    test('should have work type labels', () {
      expect(AppConstants.workTypeLabels['point'], '点工');
      expect(AppConstants.workTypeLabels['packageDay'], '包工(按天)');
      expect(AppConstants.workTypeLabels['packageQty'], '包工(按量)');
    });

    test('should have expense categories', () {
      expect(AppConstants.expenseCategories, isNotEmpty);
      expect(AppConstants.expenseCategories, contains('餐饮'));
      expect(AppConstants.expenseCategories, contains('交通'));
    });

    test('should have quantity units', () {
      expect(AppConstants.qtyUnits, contains('平方'));
      expect(AppConstants.qtyUnits, contains('米'));
      expect(AppConstants.qtyUnits, contains('立方'));
      expect(AppConstants.qtyUnits, contains('件'));
    });

    test('should have settlement type labels', () {
      expect(AppConstants.settlementTypeLabels['partial'], '部分结算');
      expect(AppConstants.settlementTypeLabels['full'], '全部结算');
    });

    test('should have default rate constants', () {
      expect(AppConstants.defaultDailyRate, 300.0);
      expect(AppConstants.defaultOvertimeRate, 50.0);
    });

    test('should have date format patterns', () {
      expect(AppConstants.dateFormatYMD, 'yyyy-MM-dd');
      expect(AppConstants.dateFormatYM, 'yyyy年MM月');
    });

    test('should expose close method', () {
      // Verify close method exists and can be called
      // (actual DB close would require DB to be open)
      expect(DatabaseHelper.instance.close, isA<Function>());
    });

    test('should expose deleteDatabase_ method', () {
      expect(DatabaseHelper.instance.deleteDatabase_, isA<Function>());
    });
  });
}
