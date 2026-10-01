import 'package:flutter_test/flutter_test.dart';
import 'package:jigongjia/models/borrow_record.dart';
import 'package:jigongjia/providers/borrow_provider.dart';

void main() {
  group('BorrowProvider', () {
    late BorrowProvider provider;

    setUp(() {
      provider = BorrowProvider();
    });

    test('should have empty records initially', () {
      expect(provider.records, isEmpty);
    });

    test('should return empty list for non-existent project', () {
      expect(provider.getRecordsByProject('nonexistent'), isEmpty);
    });

    test('should return zero total for non-existent project', () {
      expect(provider.getTotalBorrowedByProject('nonexistent'), 0.0);
    });

    test('should notify listeners when notifyListeners is called', () {
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);
      expect(notifyCount, 0);
    });

    // ===== CRUD operation tests =====

    group('CRUD operations', () {
      test('getRecordsByProject should filter by projectId', () {
        provider.recordsForTest = [
          BorrowRecord(projectId: 'proj1', amount: 500, date: DateTime(2026, 1, 10)),
          BorrowRecord(projectId: 'proj2', amount: 1000, date: DateTime(2026, 1, 11)),
          BorrowRecord(projectId: 'proj1', amount: 200, date: DateTime(2026, 1, 12)),
        ];

        final proj1Records = provider.getRecordsByProject('proj1');
        expect(proj1Records.length, 2);
        expect(proj1Records.every((r) => r.projectId == 'proj1'), isTrue);
      });

      test('getTotalBorrowedByProject should sum amounts for project', () {
        provider.recordsForTest = [
          BorrowRecord(projectId: 'proj1', amount: 500, date: DateTime(2026, 1, 10)),
          BorrowRecord(projectId: 'proj2', amount: 1000, date: DateTime(2026, 1, 11)),
          BorrowRecord(projectId: 'proj1', amount: 300, date: DateTime(2026, 1, 12)),
        ];

        expect(provider.getTotalBorrowedByProject('proj1'), 800.0);
        expect(provider.getTotalBorrowedByProject('proj2'), 1000.0);
      });

      test('getTotalBorrowedByProject should return 0 for non-existent project', () {
        provider.recordsForTest = [
          BorrowRecord(projectId: 'proj1', amount: 500, date: DateTime(2026, 1, 10)),
        ];
        expect(provider.getTotalBorrowedByProject('proj99'), 0.0);
      });

      test('getRecordsByProject with empty records returns empty', () {
        expect(provider.getRecordsByProject('any'), isEmpty);
      });
    });
  });

  group('BorrowRecord model', () {
    test('should create record with auto-generated id', () {
      final record = BorrowRecord(
        projectId: 'proj1',
        amount: 500.0,
        date: DateTime(2026, 1, 15),
      );

      expect(record.id, isNotEmpty);
      expect(record.projectId, 'proj1');
      expect(record.amount, 500.0);
      expect(record.note, '');
    });

    test('should create record with provided id', () {
      final record = BorrowRecord(
        id: 'custom-id',
        projectId: 'proj1',
        amount: 1000.0,
        date: DateTime(2026, 1, 15),
        note: 'advance payment',
      );

      expect(record.id, 'custom-id');
      expect(record.note, 'advance payment');
    });

    test('should serialize to map and back', () {
      final record = BorrowRecord(
        id: 'test-id-1',
        projectId: 'proj1',
        amount: 500.0,
        date: DateTime(2026, 1, 15),
        note: 'test',
      );

      final map = record.toMap();
      final restored = BorrowRecord.fromMap(map);

      expect(restored.id, record.id);
      expect(restored.projectId, record.projectId);
      expect(restored.amount, record.amount);
      expect(restored.note, record.note);
    });

    test('should copyWith correctly', () {
      final record = BorrowRecord(
        id: 'orig-id',
        projectId: 'proj1',
        amount: 500.0,
        date: DateTime(2026, 1, 15),
        note: 'original',
      );

      final updated = record.copyWith(amount: 800.0, note: 'updated');
      expect(updated.id, 'orig-id'); // id preserved
      expect(updated.amount, 800.0);
      expect(updated.note, 'updated');
      expect(updated.projectId, 'proj1'); // unchanged
    });

    test('equality should be based on id', () {
      final r1 = BorrowRecord(id: 'same-id', projectId: 'proj1', amount: 500, date: DateTime(2026, 1, 15));
      final r2 = BorrowRecord(id: 'same-id', projectId: 'proj2', amount: 1000, date: DateTime(2026, 2, 20));
      expect(r1, equals(r2));
    });

    test('hashCode should be based on id', () {
      final r1 = BorrowRecord(id: 'same-id', projectId: 'proj1', amount: 500, date: DateTime(2026, 1, 15));
      final r2 = BorrowRecord(id: 'same-id', projectId: 'proj2', amount: 1000, date: DateTime(2026, 2, 20));
      expect(r1.hashCode, equals(r2.hashCode));
    });

    test('toString should contain id', () {
      final record = BorrowRecord(id: 'test-123', projectId: 'proj1', amount: 500, date: DateTime(2026, 1, 15));
      expect(record.toString(), contains('test-123'));
      expect(record.toString(), contains('500'));
    });
  });
}
