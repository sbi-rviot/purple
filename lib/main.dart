// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'src/app_state.dart';
import 'src/pages/status_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyRoot());
}

class MyRoot extends StatelessWidget {
  const MyRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>(
      create: (_) => AppState()..init(),
      child: Builder(
        builder: (context) {
          // Typed access so downstream selectors compile.
          final seed = context.select<AppState, Color>((s) => s.themeSeedColor);

          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Founder Assistant',
            theme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: seed,
              brightness: Brightness.light,
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: seed,
              brightness: Brightness.dark,
            ),
            home: const StatusPage(),
          );
        },
      ),
    );
  }
}
