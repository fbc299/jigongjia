import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'package:jigongjia/core/account/account_service.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AccountService().load();
  final workProvider = WorkProvider();
  final borrowProvider = BorrowProvider();
  final settlementProvider = SettlementProvider();
  final photoProvider = PhotoEvidenceProvider();
  final projectProvider = ProjectProvider()
    ..attach(
      work: workProvider,
      borrow: borrowProvider,
      settlement: settlementProvider,
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
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => NoteProvider()),
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