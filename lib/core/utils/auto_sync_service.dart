import 'dart:convert';

import 'package:jigongjia/providers/project_provider.dart';
import 'package:jigongjia/providers/work_provider.dart';
import 'package:jigongjia/providers/borrow_provider.dart';
import 'package:jigongjia/providers/settlement_provider.dart';
import 'package:jigongjia/providers/expense_provider.dart';
import 'package:jigongjia/providers/note_provider.dart';
import 'package:jigongjia/providers/photo_evidence_provider.dart';
import 'package:jigongjia/core/utils/network_backup.dart';
import 'package:jigongjia/core/utils/photo_files.dart';

/// 记工成功后自动同步一次：全量数据固定以「自动备份_最新.json」为文件名上传，
/// 每次同步直接覆盖服务端同名备份，服务端只保留这一份最新自动备份。
/// 历史版本由服务端数据库层每小时快照保障。
class AutoSyncService {
  /// 正在同步中 / 上次同步的时间：连续保存时避免并发多次全量上传
  static bool _syncing = false;
  static DateTime? _lastSyncAt;
  static const Duration _minInterval = Duration(seconds: 5);

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
    // 连点保存/快速补录时会连续触发：上一次还没传完就跳过，别并发上传同一份数据
    if (_syncing) return '';
    final last = _lastSyncAt;
    if (last != null && DateTime.now().difference(last) < _minInterval) return '';
    _syncing = true;
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
        // 只传文件名，不带设备绝对路径（换机能还原，也不泄露目录结构）
        'photoEvidence': photo.photos
            .map((p) => {...p.toMap(), 'filePath': backupPhotoPath(p.filePath)})
            .toList(),
      });
      final result = await service.upload(data, backupName: name);
      if (result.serverOk) _lastSyncAt = DateTime.now();
      return result.serverOk ? result.name : '';
    } catch (_) {
      return '';
    } finally {
      _syncing = false;
    }
  }
}
