import 'dart:convert';

import 'package:jigongjia/providers/project_provider.dart';
import 'package:jigongjia/providers/work_provider.dart';
import 'package:jigongjia/providers/borrow_provider.dart';
import 'package:jigongjia/providers/settlement_provider.dart';
import 'package:jigongjia/providers/expense_provider.dart';
import 'package:jigongjia/providers/note_provider.dart';
import 'package:jigongjia/providers/photo_evidence_provider.dart';
import 'package:jigongjia/core/utils/network_backup.dart';

/// 记工成功后自动同步一次：全量数据按「项目名_日期_时分秒」命名上传备份服务器。
/// 服务端收到同名新备份时，自动把旧备份存为 .v01~.v10 快照（保留 10 次，再旧删除）。
class AutoSyncService {
  /// 记工成功后触发（fire-and-forget，失败不阻断 UI）。
  /// 成功返回服务端备份名，失败/无数据返回空串。
  static Future<String> syncAfterWorkRecord({
    required ProjectProvider projects,
    required WorkProvider work,
    required BorrowProvider borrow,
    required SettlementProvider settlement,
    required ExpenseProvider expense,
    required NoteProvider note,
    required PhotoEvidenceProvider photo,
  }) async {
    try {
      final service = NetworkBackupService();
      await service.load();
      if (!await service.ping()) return '';

      final now = DateTime.now();
      String two(int v) => v.toString().padLeft(2, '0');
      String four(int v) => v.toString().padLeft(4, '0');
      final projectNames =
          projects.projects.map((p) => p.name).join('+');
      final name =
          '${projectNames}_${four(now.year)}${two(now.month)}${two(now.day)}_'
          '${two(now.hour)}${two(now.minute)}${two(now.second)}.json';

      final data = json.encode({
        'version': 1,
        'exportedAt': now.toIso8601String(),
        'projects': projects.projects.map((p) => p.toMap()).toList(),
        'workRecords': work.records.map((r) => r.toMap()).toList(),
        'borrowRecords': borrow.records.map((r) => r.toMap()).toList(),
        'settlements':
            settlement.settlements.map((s) => s.toMap()).toList(),
        'expenses': expense.expenses.map((e) => e.toMap()).toList(),
        'notes': note.notes.map((n) => n.toMap()).toList(),
        'photoEvidence':
            photo.photos.map((p) => p.toMap()).toList(),
      });
      final result = await service.upload(data, backupName: name);
      return result.serverOk ? result.name : '';
    } catch (_) {
      return '';
    }
  }
}
