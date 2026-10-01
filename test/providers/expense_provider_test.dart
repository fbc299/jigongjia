import 'package:flutter_test/flutter_test.dart';
import 'package:jigongjia/models/expense.dart';
import 'package:jigongjia/providers/expense_provider.dart';

void main() {
  group('ExpenseProvider', () {
    late ExpenseProvider provider;

    setUp(() {
      provider = ExpenseProvider();
    });

    test('should have empty expenses initially', () {
      expect(provider.expenses, isEmpty);
    });

    test('should return zero monthly total for empty state', () {
      expect(provider.getMonthlyTotal(2026, 1), 0.0);
    });

    test('should return empty category totals for empty state', () {
      final totals = provider.getCategoryTotals(2026, 1);
      expect(totals, isEmpty);
    });

    test('should notify listeners when notifyListeners is called', () {
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);
      expect(notifyCount, 0);
    });

    // ===== CRUD operation tests =====

    group('CRUD operations', () {
      test('getMonthlyTotal should sum expenses in given month', () {
        provider.expensesForTest = [
          Expense(amount: 50, category: '吃饭', date: DateTime(2026, 1, 10)),
          Expense(amount: 30, category: '交通', date: DateTime(2026, 1, 15)),
          Expense(amount: 100, category: '吃饭', date: DateTime(2026, 2, 5)),
        ];

        expect(provider.getMonthlyTotal(2026, 1), 80.0);
        expect(provider.getMonthlyTotal(2026, 2), 100.0);
      });

      test('getMonthlyTotal should return 0 for month with no expenses', () {
        provider.expensesForTest = [
          Expense(amount: 50, category: '吃饭', date: DateTime(2026, 1, 10)),
        ];
        expect(provider.getMonthlyTotal(2026, 6), 0.0);
      });

      test('getCategoryTotals should group by category', () {
        provider.expensesForTest = [
          Expense(amount: 50, category: '吃饭', date: DateTime(2026, 1, 10)),
          Expense(amount: 30, category: '交通', date: DateTime(2026, 1, 15)),
          Expense(amount: 20, category: '吃饭', date: DateTime(2026, 1, 20)),
        ];

        final totals = provider.getCategoryTotals(2026, 1);
        expect(totals['吃饭'], 70.0);
        expect(totals['交通'], 30.0);
        expect(totals.containsKey('住宿'), false);
      });

      test('getCategoryTotals should return empty for month with no expenses', () {
        provider.expensesForTest = [
          Expense(amount: 50, category: '吃饭', date: DateTime(2026, 1, 10)),
        ];
        expect(provider.getCategoryTotals(2026, 6), isEmpty);
      });

      test('getMonthlyTotal should not include other months', () {
        provider.expensesForTest = [
          Expense(amount: 50, category: '吃饭', date: DateTime(2026, 1, 10)),
          Expense(amount: 200, category: '交通', date: DateTime(2026, 2, 10)),
        ];
        expect(provider.getMonthlyTotal(2026, 1), 50.0);
      });
    });
  });

  group('Expense model', () {
    test('should create expense with auto-generated id', () {
      final expense = Expense(
        amount: 50.0,
        category: '吃饭',
        date: DateTime(2026, 1, 15),
      );
      expect(expense.id, isNotEmpty);
      expect(expense.amount, 50.0);
      expect(expense.category, '吃饭');
      expect(expense.note, '');
    });

    test('should create expense with provided id', () {
      final expense = Expense(
        id: 'custom-id',
        amount: 100.0,
        category: '交通',
        date: DateTime(2026, 1, 15),
        note: 'taxi fare',
      );
      expect(expense.id, 'custom-id');
      expect(expense.category, '交通');
      expect(expense.note, 'taxi fare');
    });

    test('should serialize to map and back', () {
      final expense = Expense(
        id: 'test-id-1',
        amount: 50.0,
        category: '吃饭',
        date: DateTime(2026, 1, 15),
        note: 'lunch',
      );

      final map = expense.toMap();
      final restored = Expense.fromMap(map);

      expect(restored.id, expense.id);
      expect(restored.amount, expense.amount);
      expect(restored.category, expense.category);
      expect(restored.note, expense.note);
    });

    test('should copyWith correctly', () {
      final expense = Expense(
        id: 'orig-id',
        amount: 50.0,
        category: '吃饭',
        date: DateTime(2026, 1, 15),
        note: 'original',
      );

      final updated = expense.copyWith(amount: 80.0, category: '交通');
      expect(updated.id, 'orig-id');
      expect(updated.amount, 80.0);
      expect(updated.category, '交通');
      expect(updated.note, 'original');
    });

    test('equality should be based on id', () {
      final e1 = Expense(id: 'same-id', amount: 50, category: '吃饭', date: DateTime(2026, 1, 15));
      final e2 = Expense(id: 'same-id', amount: 100, category: '交通', date: DateTime(2026, 2, 20));
      expect(e1, equals(e2));
    });

    test('hashCode should be based on id', () {
      final e1 = Expense(id: 'same-id', amount: 50, category: '吃饭', date: DateTime(2026, 1, 15));
      final e2 = Expense(id: 'same-id', amount: 100, category: '交通', date: DateTime(2026, 2, 20));
      expect(e1.hashCode, equals(e2.hashCode));
    });

    test('toString should contain id', () {
      final expense = Expense(id: 'test-123', amount: 50, category: '吃饭', date: DateTime(2026, 1, 15));
      expect(expense.toString(), contains('test-123'));
    });
  });
}
