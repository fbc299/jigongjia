import 'dart:convert';

import 'package:jigongjia/providers/project_provider.dart';
import 'package:jigongjia/providers/work_provider.dart';
import 'package:jigongjia/providers/borrow_provider.dart';
import 'package:jigongjia/providers/settlement_provider.dart';
import 'package:jigongjia/providers/expense_provider.dart';
import 'package:jigongjia/providers/note_provider.dart';
import 'package:jigongjia/providers/photo_evidence_provider.dart';
import 'package:jigongjia/core/utils/network_backup.dart';

/// 记工成功后自动同步一次：全量数据固定以「自动备份_最新.json」为文件名上传，
/// 每次同步直接覆盖服务端同名备份，服务端只保留这一份最新自动备份。
/// 历史版本由服务端数据库层每小时快照保障。
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
      // 固定文件名：服务端同名覆盖，只保留最新一份自动备份。
      const name = '自动备份_最新.json';

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
