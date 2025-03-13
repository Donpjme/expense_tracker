import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expense_tracker/providers/theme_provider.dart';
import 'package:expense_tracker/theme/app_theme.dart';
import 'package:expense_tracker/screens/home_screen.dart';
import 'package:expense_tracker/screens/pin_auth_screen.dart';
import 'package:expense_tracker/screens/pin_setup_screen.dart';
import 'package:expense_tracker/screens/budget_setting_screen.dart';
import 'package:expense_tracker/screens/add_expense_screen.dart';
import 'package:expense_tracker/services/auth_service.dart';
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
              home: AuthCheckScreen(),
              routes: {
                '/home': (context) => const HomeScreen(),
                '/security_settings': (context) => const PinSetupScreen(),
                '/budget_setting': (context) => const BudgetSettingScreen(),
                '/add_expense': (context) => const AddExpenseScreen(),
              },
              debugShowCheckedModeBanner: false, // Remove debug banner
            );
          },
        );
      },
    );
  }
}

class AuthCheckScreen extends StatefulWidget {
  @override
  _AuthCheckScreenState createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  bool _requiresAuth = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final isPinEnabled = await _authService.isPinAuthEnabled();
    final isPinSet = await _authService.isPinSet();

    setState(() {
      _requiresAuth = isPinEnabled && isPinSet;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_requiresAuth) {
      return PinAuthScreen();
    } else {
      return HomeScreen();
    }
  }
}
