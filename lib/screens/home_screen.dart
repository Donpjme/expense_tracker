import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expense_tracker/providers/theme_provider.dart';
import 'package:expense_tracker/screens/dashboard_screen.dart';
import 'package:expense_tracker/screens/combined_expenses_screen.dart';
import 'package:expense_tracker/screens/combined_budgets_screen.dart';
import 'package:expense_tracker/screens/reports_screen.dart';
import 'package:expense_tracker/screens/currency_settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // Screen pages
  late List<Widget> _screens;

  // Keys to access screen states
  final GlobalKey<DashboardScreenState> _dashboardKey =
      GlobalKey<DashboardScreenState>();

  @override
  void initState() {
    super.initState();
    // Initialize screens
    _initializeScreens();
    // Refresh data when the screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  void _initializeScreens() {
    _screens = [
      DashboardScreen(key: _dashboardKey),
      const CombinedExpensesScreen(), // Updated to use the combined expenses screen
      const CombinedBudgetsScreen(), // Updated to use the combined budgets screen
      ReportsScreen(),
    ];
  }

  // Function to refresh data
  void _refreshData() {
    if (_dashboardKey.currentState != null) {
      _dashboardKey.currentState!.loadData();
    }

    // You can add more refresh calls for other screens if needed
    setState(() {
      // This forces the current screen to rebuild
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        actions: [
          // Currency settings button
          IconButton(
            icon: const Icon(Icons.currency_exchange),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CurrencySettingsScreen(),
                ),
              ).then((_) => _refreshData());
            },
            tooltip: 'Currency Settings',
          ),
          // Security settings button
          IconButton(
            icon: const Icon(Icons.security),
            onPressed: () {
              Navigator.pushNamed(context, '/security_settings')
                  .then((_) => _refreshData());
            },
            tooltip: 'Security Settings',
          ),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh data',
          ),
          // Theme toggle button
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return IconButton(
                icon: Icon(themeProvider.themeMode == ThemeMode.light
                    ? Icons.dark_mode
                    : themeProvider.themeMode == ThemeMode.dark
                        ? Icons.brightness_auto
                        : Icons.light_mode),
                onPressed: () {
                  themeProvider.toggleThemeMode();
                },
                tooltip: 'Toggle theme',
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          // Refresh data when switching tabs
          _refreshData();
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Expenses',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Budget',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
        ],
      ),
      floatingActionButton: _currentIndex != 3
          ? FloatingActionButton(
              // Add a unique heroTag to fix the hero animation conflict
              heroTag: 'homeScreenFAB',
              onPressed: () {
                if (_currentIndex == 0) {
                  // From dashboard, add regular expense
                  Navigator.of(context)
                      .pushNamed('/add_expense')
                      .then((_) => _refreshData());
                } else if (_currentIndex == 1) {
                  // Let the CombinedExpensesScreen handle this based on selected tab
                  // The FAB in CombinedExpensesScreen will handle the appropriate action
                } else if (_currentIndex == 2) {
                  // Let the CombinedBudgetsScreen handle this
                  // No specific action needed as budgets are managed within the screen
                }
              },
              tooltip: 'Add',
              child: const Icon(Icons.add),
            )
          : null, // Hide FAB on reports screen
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}