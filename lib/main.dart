import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expense_tracker/providers/theme_provider.dart';
import 'package:expense_tracker/theme/app_theme.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:expense_tracker/services/database_service.dart';
import 'package:logger/logger.dart';

// Import the AuthWrapper instead of directly using HomeScreen
import 'screens/auth/auth_wrapper.dart';

// Create a global logger instance
final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 50,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.none,
  ),
);

// Global navigator key for accessing context from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // Ensure Flutter is initialized before doing anything else
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database
  try {
    logger.i('Initializing database...');
    await DatabaseService().database;
    logger.i('Database initialized successfully');
  } catch (e, stackTrace) {
    logger.e('Error initializing database', error: e, stackTrace: stackTrace);
    // Continue with app launch even if database fails
  }

  // Run the app wrapped with ChangeNotifierProvider
  runApp(
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
              navigatorKey: navigatorKey,
              title: 'Expense Tracker',
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: themeProvider.themeMode,

              // Use AuthWrapper as the home widget instead of HomeScreen
              home: const AuthWrapper(),

              debugShowCheckedModeBanner: false,
            );
          },
        );
      },
    );
  }
}
