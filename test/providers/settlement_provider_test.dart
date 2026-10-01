import 'package:flutter_test/flutter_test.dart';
import 'package:jigongjia/models/settlement.dart';
import 'package:jigongjia/providers/settlement_provider.dart';

void main() {
  group('SettlementProvider', () {
    late SettlementProvider provider;

    setUp(() {
      provider = SettlementProvider();
    });

    test('should have empty settlements initially', () {
      expect(provider.settlements, isEmpty);
    });

    test('should return empty list for non-existent project', () {
      expect(provider.getSettlementsByProject('nonexistent'), isEmpty);
    });

    test('should notify listeners when notifyListeners is called', () {
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);
      expect(notifyCount, 0);
    });

    // ===== CRUD operation tests =====

    group('CRUD operations', () {
      test('getSettlementsByProject should filter by projectId', () {
        provider.settlementsForTest = [
          Settlement(projectId: 'proj1', amount: 5000, date: DateTime(2026, 1, 10)),
          Settlement(projectId: 'proj2', amount: 3000, date: DateTime(2026, 1, 11)),
          Settlement(projectId: 'proj1', amount: 2000, date: DateTime(2026, 1, 15)),
        ];

        final proj1Records = provider.getSettlementsByProject('proj1');
        expect(proj1Records.length, 2);
        expect(proj1Records.every((s) => s.projectId == 'proj1'), isTrue);
      });

      test('getSettlementsByProject should return empty for non-existent project', () {
        provider.settlementsForTest = [
          Settlement(projectId: 'proj1', amount: 5000, date: DateTime(2026, 1, 10)),
        ];
        expect(provider.getSettlementsByProject('proj99'), isEmpty);
      });

      test('settlements should be accessible via getter', () {
        provider.settlementsForTest = [
          Settlement(projectId: 'proj1', amount: 5000, date: DateTime(2026, 1, 10)),
        ];
        expect(provider.settlements.length, 1);
      });
    });
  });

  group('Settlement model', () {
    test('should create settlement with auto-generated id', () {
      final settlement = Settlement(
        projectId: 'proj1',
        amount: 5000.0,
        date: DateTime(2026, 1, 15),
      );

      expect(settlement.id, isNotEmpty);
      expect(settlement.projectId, 'proj1');
      expect(settlement.amount, 5000.0);
      expect(settlement.type, SettlementType.partial);
      expect(settlement.note, '');
    });

    test('should create full settlement', () {
      final settlement = Settlement(
        id: 'custom-id',
        projectId: 'proj1',
        amount: 10000.0,
        date: DateTime(2026, 1, 15),
        type: SettlementType.full,
        note: 'final payment',
      );

      expect(settlement.id, 'custom-id');
      expect(settlement.type, SettlementType.full);
      expect(settlement.note, 'final payment');
    });

    test('should serialize to map and back', () {
      final settlement = Settlement(
        id: 'test-id-1',
        projectId: 'proj1',
        amount: 5000.0,
        date: DateTime(2026, 1, 15),
        type: SettlementType.full,
        note: 'test',
      );

      final map = settlement.toMap();
      final restored = Settlement.fromMap(map);

      expect(restored.id, settlement.id);
      expect(restored.projectId, settlement.projectId);
      expect(restored.amount, settlement.amount);
      expect(restored.type, settlement.type);
      expect(restored.note, settlement.note);
    });

    test('should copyWith correctly', () {
      final settlement = Settlement(
        id: 'orig-id',
        projectId: 'proj1',
        amount: 5000.0,
        date: DateTime(2026, 1, 15),
        type: SettlementType.partial,
        note: 'original',
      );

      final updated = settlement.copyWith(amount: 8000.0, type: SettlementType.full);
      expect(updated.id, 'orig-id');
      expect(updated.amount, 8000.0);
      expect(updated.type, SettlementType.full);
      expect(updated.note, 'original');
      expect(updated.projectId, 'proj1');
    });

    test('equality should be based on id', () {
      final s1 = Settlement(id: 'same-id', projectId: 'proj1', amount: 5000, date: DateTime(2026, 1, 15));
      final s2 = Settlement(id: 'same-id', projectId: 'proj2', amount: 10000, date: DateTime(2026, 2, 20));
      expect(s1, equals(s2));
    });

    test('hashCode should be based on id', () {
      final s1 = Settlement(id: 'same-id', projectId: 'proj1', amount: 5000, date: DateTime(2026, 1, 15));
      final s2 = Settlement(id: 'same-id', projectId: 'proj2', amount: 10000, date: DateTime(2026, 2, 20));
      expect(s1.hashCode, equals(s2.hashCode));
    });

    test('toString should contain id', () {
      final settlement = Settlement(id: 'test-123', projectId: 'proj1', amount: 5000, date: DateTime(2026, 1, 15));
      expect(settlement.toString(), contains('test-123'));
    });
  });
}
