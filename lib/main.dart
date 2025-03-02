import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expense_tracker/providers/theme_provider.dart';
import 'package:expense_tracker/theme/app_theme.dart';
import 'package:expense_tracker/screens/home_screen.dart';
import 'package:dynamic_color/dynamic_color.dart';

void main() {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    // Provide ThemeProvider to the widget tree
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return Consumer<ThemeProvider>(
          builder: (context, themeProvider, _) {
            return MaterialApp(
              title: 'Expense Tracker',
              theme: AppTheme.light(), // Light theme from our theme file
              darkTheme: AppTheme.dark(), // Dark theme from our theme file
              themeMode:
                  themeProvider.themeMode, // Current theme mode from provider
              home: const HomeScreen(),
              debugShowCheckedModeBanner: false, // Remove debug banner
            );
          },
        );
      },
    );
  }
}
