import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/app_database.dart';
import 'providers/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = AppDatabase();
  final appState = AppState(database);
  await appState.loadInitialData();

  runApp(
    ChangeNotifierProvider<AppState>(
      create: (_) => appState,
      child: const DeutschFlowApp(),
    ),
  );
}
