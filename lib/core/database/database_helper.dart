import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import '../constants/app_constants.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _database;

  /// work_records 同日唯一索引名（_onCreate 与 v2 迁移共用同一个定义）
  static const String _idxWorkRecordDay = 'idx_work_records_project_date';

  Future<Database> get database async {
    try {
      if (_database != null) return _database!;
      _database = await _initDatabase();
      return _database!;
    } catch (e) {
      debugPrint('获取数据库失败: $e');
      rethrow;
    }
  }

  Future<Database> _initDatabase() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, AppConstants.dbName);
      return await openDatabase(
        path,
        version: AppConstants.dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onConfigure: (db) async {
          await db.rawQuery('PRAGMA journal_mode=WAL');
          await db.rawQuery('PRAGMA foreign_keys=ON');
        },
      );
    } catch (e) {
      debugPrint('初始化数据库失败: $e');
      rethrow;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    try {
    await db.execute('''
      CREATE TABLE ${AppConstants.tableProjects} (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        isArchived INTEGER NOT NULL DEFAULT 0,
        defaultDailyRate REAL NOT NULL DEFAULT 300.0,
        defaultOvertimeRate REAL NOT NULL DEFAULT 50.0,
        defaultPackageDayRate REAL NOT NULL DEFAULT 0.0,
        defaultPackageQtyRate REAL NOT NULL DEFAULT 0.0,
        defaultQtyUnit TEXT NOT NULL DEFAULT '平方'
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.tableWorkRecords} (
        id TEXT PRIMARY KEY,
        projectId TEXT NOT NULL,
        date INTEGER NOT NULL,
        type TEXT NOT NULL DEFAULT 'point',
        days REAL NOT NULL DEFAULT 0.0,
        dailyRate REAL NOT NULL DEFAULT 300.0,
        overtimeHours REAL NOT NULL DEFAULT 0.0,
        overtimeRate REAL NOT NULL DEFAULT 0.0,
        packageDays REAL NOT NULL DEFAULT 0.0,
        packageDayRate REAL NOT NULL DEFAULT 0.0,
        quantity REAL NOT NULL DEFAULT 0.0,
        qtyUnit TEXT NOT NULL DEFAULT '平方',
        qtyUnitPrice REAL NOT NULL DEFAULT 0.0,
        totalWage REAL NOT NULL DEFAULT 0.0,
        note TEXT NOT NULL DEFAULT '',
        isRest INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER NOT NULL,
        FOREIGN KEY (projectId) REFERENCES ${AppConstants.tableProjects} (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.tableBorrowRecords} (
        id TEXT PRIMARY KEY,
        projectId TEXT NOT NULL,
        amount REAL NOT NULL,
        date INTEGER NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        createdAt INTEGER NOT NULL,
        FOREIGN KEY (projectId) REFERENCES ${AppConstants.tableProjects} (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.tableSettlements} (
        id TEXT PRIMARY KEY,
        projectId TEXT NOT NULL,
        amount REAL NOT NULL,
        date INTEGER NOT NULL,
        type TEXT NOT NULL DEFAULT 'partial',
        note TEXT NOT NULL DEFAULT '',
        createdAt INTEGER NOT NULL,
        FOREIGN KEY (projectId) REFERENCES ${AppConstants.tableProjects} (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.tablePhotoEvidence} (
        id TEXT PRIMARY KEY,
        projectId TEXT NOT NULL,
        workRecordId TEXT,
        filePath TEXT NOT NULL,
        thumbPath TEXT NOT NULL DEFAULT '',
        projectName TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        createdAt INTEGER NOT NULL,
        FOREIGN KEY (projectId) REFERENCES ${AppConstants.tableProjects} (id) ON DELETE CASCADE,
        FOREIGN KEY (workRecordId) REFERENCES ${AppConstants.tableWorkRecords} (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.tableExpenses} (
        id TEXT PRIMARY KEY,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        date INTEGER NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        createdAt INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.tableNotes} (
        id TEXT PRIMARY KEY,
        projectId TEXT,
        content TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        FOREIGN KEY (projectId) REFERENCES ${AppConstants.tableProjects} (id) ON DELETE CASCADE
      )
    ''');

    // Indexes for common queries
    await db.execute(
      'CREATE INDEX idx_work_records_project ON ${AppConstants.tableWorkRecords} (projectId)',
    );
    await db.execute(
      'CREATE INDEX idx_work_records_date ON ${AppConstants.tableWorkRecords} (date)',
    );
    // 同一项目同一天只允许一条记工记录（S3：防同日重复记工导致工资重复累计）。
    // 与 _onUpgrade 中的 v2 迁移保持完全一致，否则新装用户拿不到该约束。
    await db.execute(
      'CREATE UNIQUE INDEX $_idxWorkRecordDay ON ${AppConstants.tableWorkRecords} (projectId, date)',
    );
    await db.execute(
      'CREATE INDEX idx_borrow_records_project ON ${AppConstants.tableBorrowRecords} (projectId)',
    );
    await db.execute(
      'CREATE INDEX idx_settlements_project ON ${AppConstants.tableSettlements} (projectId)',
    );
    await db.execute(
      'CREATE INDEX idx_photo_evidence_project ON ${AppConstants.tablePhotoEvidence} (projectId)',
    );
    await db.execute(
      'CREATE INDEX idx_expenses_date ON ${AppConstants.tableExpenses} (date)',
    );
    await db.execute(
      'CREATE INDEX idx_notes_project ON ${AppConstants.tableNotes} (projectId)',
    );
    } catch (e) {
      debugPrint('创建数据库表失败: $e');
      rethrow;
    }
  }

  /// 数据库升级入口。
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    try {
      if (oldVersion < 2) {
        await _migrateToV2DailyUnique(db);
      }
      if (oldVersion < 3) {
        await _migrateToV3PhotoThumb(db);
      }
    } catch (e) {
      debugPrint('升级数据库失败: $e');
      rethrow;
    }
  }

  /// v2 → v3：photo_evidence 增加 thumbPath（列表用 400px 缩略图）。
  /// 老数据留空串，展示时回退到原图，不需要回填。
  Future<void> _migrateToV3PhotoThumb(Database db) async {
    final columns = await db.rawQuery(
      'PRAGMA table_info(${AppConstants.tablePhotoEvidence})',
    );
    final hasColumn = columns.any((c) => c['name'] == 'thumbPath');
    if (!hasColumn) {
      await db.execute(
        "ALTER TABLE ${AppConstants.tablePhotoEvidence} "
        "ADD COLUMN thumbPath TEXT NOT NULL DEFAULT ''",
      );
    }
  }

  /// v1 → v2：给 work_records 加 UNIQUE(projectId, date)（同日只允许一条记工）。
  ///
  /// 老库里有两类数据必须先处理，否则 CREATE UNIQUE INDEX 抛错 → openDatabase 失败
  /// → App 直接打不开：
  /// 1) `date` 存的是带时分的时间戳（旧版直接写 DateTime.now()），同日多条因此能共存；
  /// 2) 同一项目同一天确实存在多条记录（S3 重复记工）。
  /// 处理策略：日期归一到本地 0 点 → 同日多条合并为一条（工天/加班/数量/金额累加、
  /// 备注拼接、照片引用改挂主记录）→ 建唯一索引。
  Future<void> _migrateToV2DailyUnique(Database db) async {
    // 1) 日期归一化到本地当天 0 点
    final rows = await db.query(
      AppConstants.tableWorkRecords,
      columns: ['id', 'date'],
    );
    for (final row in rows) {
      final oldMs = (row['date'] as num?)?.toInt();
      if (oldMs == null) continue;
      final dt = DateTime.fromMillisecondsSinceEpoch(oldMs);
      final newMs = DateTime(dt.year, dt.month, dt.day).millisecondsSinceEpoch;
      if (newMs != oldMs) {
        await db.update(
          AppConstants.tableWorkRecords,
          {'date': newMs},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    }

    // 2) 合并同项目同一天的多条记录：保留一条为主记录，其余累加后删除
    final groups = await db.rawQuery('''
      SELECT projectId, date, COUNT(*) AS c
      FROM ${AppConstants.tableWorkRecords}
      GROUP BY projectId, date
      HAVING c > 1
    ''');
    for (final g in groups) {
      final projectId = g['projectId'] as String;
      final dateMs = (g['date'] as num).toInt();
      final dups = await db.query(
        AppConstants.tableWorkRecords,
        where: 'projectId = ? AND date = ?',
        whereArgs: [projectId, dateMs],
        orderBy: 'createdAt ASC, id ASC',
      );
      if (dups.length < 2) continue;
      // 主记录优先取「非休息日」的那条（休息日金额恒为 0，合并后语义更贴近实际）
      final base = dups.firstWhere(
        (m) => (m['isRest'] as num?)?.toInt() != 1,
        orElse: () => dups.first,
      );
      final others = dups.where((m) => m['id'] != base['id']).toList();
      double sum(String key) => others.fold<double>(
            0,
            (acc, m) => acc + ((m[key] as num?)?.toDouble() ?? 0),
          );
      double own(String key) => (base[key] as num?)?.toDouble() ?? 0;

      final mergedNotes = <String>[
        if (((base['note'] as String?) ?? '').isNotEmpty) base['note'] as String,
        for (final m in others)
          if (((m['note'] as String?) ?? '').isNotEmpty) m['note'] as String,
      ];

      final mergedWage = own('totalWage') + sum('totalWage');
      final baseType = (base['type'] as String?) ?? 'point';

      // 合并后必须保持「字段重算 == totalWage」，否则用户打开这条记录点一次保存，
      // work_entry_screen 的 _wage 会按 type 从字段重算，金额就被静默改掉。
      // 只有「类型相同且单价相同」时，字段直接相加才自洽；否则退化成点工，
      // 用 days = 金额 / 日薪 反推，保证金额一分不差（备注里注明是合并记录）。
      final sameTypeAndRate = dups.every((m) {
        if (((m['type'] as String?) ?? 'point') != baseType) return false;
        switch (baseType) {
          case 'packageDay':
            return (m['packageDayRate'] as num?)?.toDouble() == own('packageDayRate');
          case 'packageQty':
            return (m['qtyUnitPrice'] as num?)?.toDouble() == own('qtyUnitPrice');
          default:
            return (m['dailyRate'] as num?)?.toDouble() == own('dailyRate') &&
                (m['overtimeRate'] as num?)?.toDouble() == own('overtimeRate');
        }
      });

      final Map<String, Object?> mergedFields;
      if (sameTypeAndRate) {
        mergedFields = {
          'days': own('days') + sum('days'),
          'overtimeHours': own('overtimeHours') + sum('overtimeHours'),
          'packageDays': own('packageDays') + sum('packageDays'),
          'quantity': own('quantity') + sum('quantity'),
          'totalWage': mergedWage,
          'note': mergedNotes.toSet().join(' / '),
        };
      } else {
        final rate = own('dailyRate') > 0
            ? own('dailyRate')
            : ((base['dailyRate'] as num?)?.toDouble() ?? 300.0);
        final safeRate = rate > 0 ? rate : 300.0;
        mergedFields = {
          'type': 'point',
          'days': mergedWage / safeRate,
          'dailyRate': safeRate,
          'overtimeHours': 0.0,
          'overtimeRate': 0.0,
          'packageDays': 0.0,
          'packageDayRate': 0.0,
          'quantity': 0.0,
          'qtyUnitPrice': 0.0,
          'totalWage': mergedWage,
          'note': [
            ...mergedNotes.toSet(),
            '（系统合并同日多条记工，金额已保留，工天按日薪折算）',
          ].join(' / '),
        };
      }

      await db.update(
        AppConstants.tableWorkRecords,
        mergedFields,
        where: 'id = ?',
        whereArgs: [base['id']],
      );

      for (final m in others) {
        // 照片引用改挂主记录，避免 ON DELETE SET NULL 丢失关联
        await db.update(
          AppConstants.tablePhotoEvidence,
          {'workRecordId': base['id']},
          where: 'workRecordId = ?',
          whereArgs: [m['id']],
        );
        await db.delete(
          AppConstants.tableWorkRecords,
          where: 'id = ?',
          whereArgs: [m['id']],
        );
      }
      debugPrint(
        '迁移合并同日重复记工: project=$projectId date=$dateMs ${dups.length} 条 → 1 条',
      );
    }

    // 3) 建唯一索引。极端情况下若仍有残留重复，不让它挡住启动（否则用户彻底打不开 App），
    //    记日志降级；上层 UI 仍有「同日已记则转编辑」的兜底。
    try {
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS $_idxWorkRecordDay '
        'ON ${AppConstants.tableWorkRecords} (projectId, date)',
      );
    } catch (e) {
      debugPrint('创建 work_records 同日唯一索引失败（已跳过）: $e');
    }
  }

  Future<void> close() async {
    try {
      final db = _database;
      if (db != null && db.isOpen) {
        await db.close();
        _database = null;
      }
    } catch (e) {
      debugPrint('关闭数据库失败: $e');
      rethrow;
    }
  }

  Future<void> deleteDatabase_() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, AppConstants.dbName);
      await deleteDatabase(path);
      _database = null;
    } catch (e) {
      debugPrint('删除数据库失败: $e');
      rethrow;
    }
  }

  /// 在事务中执行数据库操作
  Future<T> txn<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return await db.transaction(action);
  }
}
