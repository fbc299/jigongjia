import 'package:flutter_test/flutter_test.dart';
import 'package:jigongjia/core/utils/work_stats.dart';
import 'package:jigongjia/models/work_record.dart';

WorkRecord rec({
  required DateTime date,
  WorkType type = WorkType.point,
  double days = 1,
  double packageDays = 0,
  double quantity = 0,
  bool isRest = false,
}) {
  return WorkRecord(
    projectId: 'p1',
    date: date,
    type: type,
    days: days,
    dailyRate: 300,
    packageDays: packageDays,
    packageDayRate: 200,
    quantity: quantity,
    qtyUnitPrice: 10,
    totalWage: 0,
    isRest: isRest,
  );
}

void main() {
  group('sumWorkDays 按天合并', () {
    test('同一天两条计件只算 1 天（不再逐条相加）', () {
      final d = DateTime(2026, 11, 1);
      final days = sumWorkDays([
        rec(date: d, type: WorkType.packageQty, quantity: 30),
        rec(date: d, type: WorkType.packageQty, quantity: 50),
      ]);
      expect(days, 1.0);
    });

    test('同一天点工半天 + 计件：只算 0.5 天，计件不再叠加', () {
      final d = DateTime(2026, 11, 2);
      final days = sumWorkDays([
        rec(date: d, days: 0.5),
        rec(date: d, type: WorkType.packageQty, quantity: 20),
      ]);
      expect(days, 0.5);
    });

    test('同一天两条点工累加（1 + 0.5 = 1.5 天）', () {
      final d = DateTime(2026, 11, 3);
      final days = sumWorkDays([
        rec(date: d, days: 1),
        rec(date: d, days: 0.5),
      ]);
      expect(days, 1.5);
    });

    test('不同天的计件各算 1 天', () {
      final days = sumWorkDays([
        rec(date: DateTime(2026, 11, 4), type: WorkType.packageQty, quantity: 10),
        rec(date: DateTime(2026, 11, 5), type: WorkType.packageQty, quantity: 10),
      ]);
      expect(days, 2.0);
    });

    test('休息日不计、数量为 0 的计件不计', () {
      final d = DateTime(2026, 11, 6);
      final days = sumWorkDays([
        rec(date: d, isRest: true),
        rec(date: d, type: WorkType.packageQty, quantity: 0),
      ]);
      expect(days, 0.0);
    });

    test('包工按天按 packageDays 计', () {
      final days = sumWorkDays([
        rec(date: DateTime(2026, 11, 7), type: WorkType.packageDay, packageDays: 2),
      ]);
      expect(days, 2.0);
    });
  });

  test('formatDays 整数不带小数点', () {
    expect(formatDays(3), '3');
    expect(formatDays(2.5), '2.5');
  });
}
