import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../constants/app_constants.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _database;

  Future<Database> get database async {
    try {
      if (_database != null) return _database!;
      _database = await _initDatabase();
      return _database!;
    } catch (e) {
      print('获取数据库失败: $e');
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
        onConfigure: (db) async {
          await db.rawQuery('PRAGMA journal_mode=WAL');
          await db.rawQuery('PRAGMA foreign_keys=ON');
        },
      );
    } catch (e) {
      print('初始化数据库失败: $e');
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
      print('创建数据库表失败: $e');
      rethrow;
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
      print('关闭数据库失败: $e');
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
      print('删除数据库失败: $e');
      rethrow;
    }
  }

  /// 在事务中执行数据库操作
  Future<T> txn<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return await db.transaction(action);
  }

  /// 批量执行数据库操作
  Future<void> batchOp(void Function(Batch batch) operations) async {
    final db = await database;
    final batch = db.batch();
    operations(batch);
    await batch.commit();
  }
}
