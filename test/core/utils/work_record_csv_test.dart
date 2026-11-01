import 'package:flutter_test/flutter_test.dart';
import 'package:jigongjia/core/utils/work_record_csv.dart';
import 'package:jigongjia/models/work_record.dart';

void main() {
  WorkRecord rec({
    required DateTime date,
    double days = 1,
    String note = '',
    WorkType type = WorkType.point,
    double packageDays = 0,
    double quantity = 0,
  }) =>
      WorkRecord(
        projectId: 'p1',
        date: date,
        type: type,
        days: days,
        dailyRate: 300,
        totalWage: days * 300,
        packageDays: packageDays,
        quantity: quantity,
        note: note,
      );

  test('CSV 带 BOM、表头和合计行', () {
    final csv = WorkRecordCsv.build(
      records: [rec(date: DateTime(2026, 11, 1))],
      projectNames: {'p1': '梅花工地'},
    );
    expect(csv.startsWith('\uFEFF'), isTrue);
    expect(csv, contains('日期,项目,类型,工天,加班(小时),金额(元),备注'));
    expect(csv, contains('梅花工地'));
    expect(csv, contains('合计'));
    expect(csv, contains('300.00'));
  });

  test('逗号/引号/换行会按 RFC4180 转义', () {
    final csv = WorkRecordCsv.build(
      records: [rec(date: DateTime(2026, 11, 2), note: '晚上加班，加了"两"小时\n搬砖')],
      projectNames: {'p1': 'A,B'},
    );
    expect(csv, contains('"A,B"'));
    expect(csv, contains('"晚上加班，加了""两""小时'));
  });

  test('合计按真值工天（半天算 0.5，休息不计）', () {
    final csv = WorkRecordCsv.build(
      records: [
        rec(date: DateTime(2026, 11, 1), days: 0.5),
        rec(date: DateTime(2026, 11, 2), days: 1.5),
      ],
      projectNames: {'p1': '梅花'},
    );
    // 0.5 * 300 + 1.5 * 300 = 600
    expect(csv, contains('2,,')); // 合计算出的 2 工天
    expect(csv, contains('600.00'));
  });
}
