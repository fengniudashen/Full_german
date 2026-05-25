import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'pages/home_shell.dart';
import 'providers/app_state.dart';
import 'theme/app_theme.dart';

class DeutschFlowApp extends StatelessWidget {
  const DeutschFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<AppState>().themeMode;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DeutschFlow',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: const HomeShell(),
    );
  }
}
