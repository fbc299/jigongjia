import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jigongjia/providers/project_provider.dart';
import 'package:jigongjia/providers/work_provider.dart';
import 'package:jigongjia/providers/borrow_provider.dart';
import 'package:jigongjia/providers/settlement_provider.dart';
import 'package:jigongjia/providers/expense_provider.dart';
import 'package:jigongjia/providers/note_provider.dart';
import 'package:jigongjia/providers/photo_evidence_provider.dart';
import 'package:jigongjia/core/utils/network_backup.dart';
import 'package:jigongjia/core/utils/photo_files.dart';

/// 数据变更后自动同步：全量数据固定以「自动备份_最新.json」为文件名上传，
/// 每次同步直接覆盖服务端同名备份，服务端只保留这一份最新自动备份。
/// 历史版本由服务端数据库层每小时快照保障。
///
/// 触发方式（v1.1.29 起）：任何数据 provider 变动都会 [markDirty]，
/// 30 秒内的多次变动只上传一次（debounce）。以前只有「新增记工」才同步，
/// 借支/结算/开支/笔记改动不会上云，用户以为备份了其实没备。
class AutoSyncService {
  static bool _syncing = false;
  static DateTime? _lastSyncAt;
  static const Duration _minInterval = Duration(seconds: 5);

  /// 变动后等待多久再同步：连续编辑时不至于每次都全量上传
  static const Duration _debounce = Duration(seconds: 30);

  static Timer? _debounceTimer;
  static bool _dirty = false;

  static const String prefLastSuccess = 'auto_sync_last_ok_at';
  static const String prefLastError = 'auto_sync_last_error';

  // 注册的 provider（main.dart 启动时注入）
  static ProjectProvider? _projects;
  static WorkProvider? _work;
  static BorrowProvider? _borrow;
  static SettlementProvider? _settlement;
  static ExpenseProvider? _expense;
  static NoteProvider? _note;
  static PhotoEvidenceProvider? _photo;

  /// 在 main() 里调用一次：注册数据源 + 挂变更监听
  static void register({
    required ProjectProvider projects,
    required WorkProvider work,
    required BorrowProvider borrow,
    required SettlementProvider settlement,
    required ExpenseProvider expense,
    required NoteProvider note,
    required PhotoEvidenceProvider photo,
  }) {
    _projects = projects;
    _work = work;
    _borrow = borrow;
    _settlement = settlement;
    _expense = expense;
    _note = note;
    _photo = photo;

    for (final notifier in <ChangeNotifier?>[work, borrow, settlement, expense, note, photo]) {
      notifier?.addListener(markDirty);
    }
  }

  /// 数据变了：等 30 秒再同步（期间再变就重新计时）
  static void markDirty() {
    _dirty = true;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      if (_dirty) syncNow();
    });
  }

  /// 立即同步（自动触发或用户手动点「立即备份」）
  static Future<String> syncNow() async {
    _dirty = false;
    _debounceTimer?.cancel();
    final projects = _projects;
    final work = _work;
    final borrow = _borrow;
    final settlement = _settlement;
    final expense = _expense;
    final note = _note;
    final photo = _photo;
    if (projects == null ||
        work == null ||
        borrow == null ||
        settlement == null ||
        expense == null ||
        note == null ||
        photo == null) {
      return '';
    }
    return syncAfterWorkRecord(
      projects: projects,
      work: work,
      borrow: borrow,
      settlement: settlement,
      expense: expense,
      note: note,
      photo: photo,
    );
  }

  /// 真正的上传逻辑（记工保存后也走这里，立刻同步一次）
  /// 成功返回服务端备份名，失败/无配置返回空串。
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
      if (!await service.ping()) {
        await _recordError('连不上备份服务器');
        return '';
      }
      if (service.token.isEmpty) {
        await _recordError('没有备份口令，备份未加密，已跳过自动上传');
        return '';
      }

      final now = DateTime.now();
      // 固定文件名：服务端同名覆盖，只保留最新一份自动备份。
      const name = '自动备份_最新.json';

      final data = json.encode({
        'version': 1,
        'exportedAt': now.toIso8601String(),
        'projects': projects.projects.map((p) => p.toMap()).toList(),
        'workRecords': work.records.map((r) => r.toMap()).toList(),
        'borrowRecords': borrow.records.map((b) => b.toMap()).toList(),
        'settlements': settlement.settlements.map((s) => s.toMap()).toList(),
        'expenses': expense.expenses.map((e) => e.toMap()).toList(),
        'notes': note.notes.map((n) => n.toMap()).toList(),
        // 只传文件名，不带设备绝对路径（换机能还原，也不泄露目录结构）
        'photoEvidence': photo.photos.map((p) => {
              ...p.toMap(),
              'filePath': backupPhotoPath(p.filePath),
              'thumbPath': p.thumbPath.isEmpty ? '' : backupPhotoPath(p.thumbPath),
            }).toList(),
      });
      final result = await service.upload(data, backupName: name);
      if (result.serverOk) {
        _lastSyncAt = DateTime.now();
        await _recordSuccess(_lastSyncAt!);
        return result.name;
      }
      await _recordError('上传失败：${result.message}');
      return '';
    } catch (e) {
      await _recordError('$e');
      return '';
    } finally {
      _syncing = false;
    }
  }

  static Future<void> _recordSuccess(DateTime at) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefLastSuccess, at.toIso8601String());
      await prefs.remove(prefLastError);
    } catch (_) {}
  }

  static Future<void> _recordError(String message) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefLastError, message);
    } catch (_) {}
  }

  /// 设置页展示用：上次成功时间 + 上次失败原因
  static Future<({DateTime? lastOk, String? lastError})> status() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ok = prefs.getString(prefLastSuccess);
      return (
        lastOk: ok == null ? null : DateTime.tryParse(ok),
        lastError: prefs.getString(prefLastError),
      );
    } catch (_) {
      return (lastOk: null, lastError: null);
    }
  }
}
