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
