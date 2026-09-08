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
import 'package:jigongjia/app.dart';

void main() {
  final workProvider = WorkProvider();
  final borrowProvider = BorrowProvider();
  final settlementProvider = SettlementProvider();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProjectProvider()),
        ChangeNotifierProvider.value(value: workProvider),
        ChangeNotifierProvider.value(value: borrowProvider),
        ChangeNotifierProvider.value(value: settlementProvider),
        ChangeNotifierProvider(
          create: (_) =>
              StatsProvider(workProvider, borrowProvider, settlementProvider),
        ),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => NoteProvider()),
        ChangeNotifierProvider(create: (_) => PhotoEvidenceProvider()),
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