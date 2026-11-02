import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'package:jigongjia/core/theme/app_theme.dart';
import 'package:jigongjia/providers/project_provider.dart';
import 'package:jigongjia/providers/work_provider.dart';
import 'package:jigongjia/providers/borrow_provider.dart';
import 'package:jigongjia/providers/settlement_provider.dart';
import 'package:jigongjia/providers/stats_provider.dart';
import 'package:jigongjia/providers/expense_provider.dart';
import 'package:jigongjia/providers/note_provider.dart';
import 'package:jigongjia/providers/photo_evidence_provider.dart';
import 'package:jigongjia/core/utils/auto_sync_service.dart';
import 'package:jigongjia/app.dart';

void main() {
  // 必须先初始化绑定，再碰 SharedPreferences/文件等插件
  WidgetsFlutterBinding.ensureInitialized();

  // 全局错误兜底：以前后台异常直接静默丢失，用户只看到「没反应」
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter 异常: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('未捕获异常: $error\n$stack');
    return true;
  };

  final workProvider = WorkProvider();
  final borrowProvider = BorrowProvider();
  final settlementProvider = SettlementProvider();
  final photoProvider = PhotoEvidenceProvider();
  final expenseProvider = ExpenseProvider();
  final noteProvider = NoteProvider();
  final projectProvider = ProjectProvider()
    ..attach(
      work: workProvider,
      borrow: borrowProvider,
      settlement: settlementProvider,
      photo: photoProvider,
      expense: expenseProvider,
      note: noteProvider,
    );
  // 任何数据变动 → 30 秒后自动上传一次（debounce），不再只在新增记工时同步
  AutoSyncService.register(
    projects: projectProvider,
    work: workProvider,
    borrow: borrowProvider,
    settlement: settlementProvider,
    expense: expenseProvider,
    note: noteProvider,
    photo: photoProvider,
  );


  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: projectProvider),
        ChangeNotifierProvider.value(value: workProvider),
        ChangeNotifierProvider.value(value: borrowProvider),
        ChangeNotifierProvider.value(value: settlementProvider),
        ChangeNotifierProvider(
          create: (_) =>
              StatsProvider(workProvider, borrowProvider, settlementProvider),
        ),
        ChangeNotifierProvider.value(value: expenseProvider),
        ChangeNotifierProvider.value(value: noteProvider),
        ChangeNotifierProvider.value(value: photoProvider),
      ],
      child: MaterialApp(
        title: '格格记工',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [
          Locale('zh', 'CN'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const AppShell(),
      ),
    ),
  );
}