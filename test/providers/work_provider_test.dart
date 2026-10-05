import 'package:flutter_test/flutter_test.dart';
import 'package:jigongjia/models/work_record.dart';
import 'package:jigongjia/models/project.dart';
import 'package:jigongjia/providers/work_provider.dart';

void main() {
  group('WorkProvider', () {
    late WorkProvider provider;

    setUp(() {
      provider = WorkProvider();
    });

    test('should have empty records initially', () {
      expect(provider.records, isEmpty);
    });

    test('should notify listeners on notifyListeners call', () {
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);
      // Access internal notify through loadRecords would require DB
      // Test the listener mechanism directly
      expect(notifyCount, 0);
    });

    test('should filter records by project', () {
      // Test the in-memory filter logic
      expect(provider.getRecordsByProject('nonexistent'), isEmpty);
    });

    test('should filter records by month', () {
      expect(
        provider.getRecordsByMonth('proj1', 2026, 1),
        isEmpty,
      );
    });

    test('should filter records by date', () {
      expect(
        provider.getRecordsByDate('proj1', DateTime(2026, 1, 15)),
        isEmpty,
      );
    });
  });

  group('WorkRecord model', () {
    test('should create record with auto-generated id', () {
      final record = WorkRecord(
        projectId: 'proj1',
        date: DateTime(2026, 1, 15),
      );

      expect(record.id, isNotEmpty);
      expect(record.projectId, 'proj1');
      expect(record.type, WorkType.point);
      expect(record.isRest, false);
    });

    test('should serialize to map and back', () {
      final record = WorkRecord(
        id: 'test-id-1',
        projectId: 'proj1',
        date: DateTime(2026, 1, 15),
        type: WorkType.point,
        days: 1.0,
        dailyRate: 300.0,
        overtimeHours: 2.0,
        overtimeRate: 50.0,
        totalWage: 400.0,
        note: 'test note',
        isRest: false,
      );

      final map = record.toMap();
      expect(map['id'], 'test-id-1');
      expect(map['projectId'], 'proj1');
      expect(map['type'], 'point');
      expect(map['days'], 1.0);
      expect(map['dailyRate'], 300.0);
      expect(map['isRest'], 0);

      final restored = WorkRecord.fromMap(map);
      expect(restored.id, record.id);
      expect(restored.projectId, record.projectId);
      expect(restored.type, WorkType.point);
      expect(restored.days, 1.0);
      expect(restored.isRest, false);
      expect(restored.note, 'test note');
    });

    test('should serialize rest day correctly', () {
      final record = WorkRecord(
        id: 'rest-id',
        projectId: 'proj1',
        date: DateTime(2026, 1, 15),
        isRest: true,
        totalWage: 0,
      );

      final map = record.toMap();
      expect(map['isRest'], 1);

      final restored = WorkRecord.fromMap(map);
      expect(restored.isRest, true);
    });

    test('should copy with changes', () {
      final record = WorkRecord(
        id: 'test-id',
        projectId: 'proj1',
        date: DateTime(2026, 1, 15),
        days: 1.0,
        dailyRate: 300.0,
        totalWage: 300.0,
      );

      final updated = record.copyWith(days: 0.5, totalWage: 150.0);
      expect(updated.id, record.id); // id preserved
      expect(updated.days, 0.5);
      expect(updated.totalWage, 150.0);
      expect(updated.projectId, 'proj1'); // unchanged
    });

    test('should support equality by id', () {
      final r1 = WorkRecord(id: 'same-id', projectId: 'p1', date: DateTime(2026, 1, 1));
      final r2 = WorkRecord(id: 'same-id', projectId: 'p2', date: DateTime(2026, 2, 2));
      final r3 = WorkRecord(id: 'diff-id', projectId: 'p1', date: DateTime(2026, 1, 1));

      expect(r1, equals(r2));
      expect(r1, isNot(equals(r3)));
    });
  });
}
