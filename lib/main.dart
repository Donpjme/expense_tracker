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
import 'package:expense_tracker/services/database_service.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:logger/logger.dart';

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
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: themeProvider.themeMode,
              home: AuthCheckScreen(),
              routes: {
                '/home': (context) => const HomeScreen(),
                '/security_settings': (context) => const PinSetupScreen(),
                '/budget_setting': (context) => const BudgetSettingScreen(),
                '/add_expense': (context) => const AddExpenseScreen(),
              },
              debugShowCheckedModeBanner: false,
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
  final DatabaseService _databaseService = DatabaseService();
  final Logger _logger = Logger();
  bool _isLoading = true;
  bool _isPinSet = false;

  @override
  void initState() {
    super.initState();
    _checkPinStatus();
    _processRecurringItems();
  }

  /// Process any recurring expenses and budgets that are due
  Future<void> _processRecurringItems() async {
    try {
      await _databaseService.checkAndAddRecurringExpenses();
      await _databaseService.checkAndAddRecurringBudgets();
    } catch (e) {
      _logger.e('Error processing recurring items: $e');
    }
  }

  /// Check if PIN is set for authentication
  Future<void> _checkPinStatus() async {
    try {
      final isPinSet = await _authService.isPinSet();
      final isPinEnabled = await _authService.isPinAuthEnabled();

      if (!mounted) return;

      setState(() {
        _isPinSet = isPinSet && isPinEnabled;
        _isLoading = false;
      });
    } catch (e) {
      _logger.e('Error checking PIN status: $e');
      if (!mounted) return;

      setState(() {
        _isPinSet = false; // Default to setup mode on error
        _isLoading = false;
      });
    }
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

    // Enforce PIN setup if it's not set
    if (!_isPinSet) {
      return PinSetupScreen(
        isFirstTimeSetup: true,
        onSetupComplete: () {
          Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const HomeScreen()));
        },
      );
    }

    // If PIN is set, proceed to authentication
    return PinAuthScreen();
  }
}
