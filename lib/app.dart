import 'package:flutter/material.dart';

import 'pages/home_shell.dart';
import 'theme/app_theme.dart';

class DeutschFlowApp extends StatelessWidget {
  const DeutschFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DeutschFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const HomeShell(),
    );
  }
}
