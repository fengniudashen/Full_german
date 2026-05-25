import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/app_database.dart';
import 'providers/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = AppDatabase();
  final appState = AppState(database);
  await appState.loadInitialData();

  runApp(
    ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: const DeutschFlowApp(),
    ),
  );
}
