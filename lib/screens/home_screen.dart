import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expense_tracker/providers/theme_provider.dart';
import 'package:expense_tracker/screens/dashboard_screen.dart';
import 'package:expense_tracker/screens/expenses_list_screen.dart';
import 'package:expense_tracker/screens/budget_setting_screen.dart';
import 'package:expense_tracker/screens/reports_screen.dart';
import 'package:expense_tracker/screens/add_expense_screen.dart';
import 'package:expense_tracker/screens/recurring_expense_screen.dart';
import 'package:expense_tracker/screens/recurring_budget_screen.dart';
import 'package:expense_tracker/screens/recurring_items_screen.dart';

class HomeScreen extends StatefulWidget {
  // Auth parameters
  final bool isAuthenticated;
  final VoidCallback onAuthenticationNeeded;
  final VoidCallback onLogout;

  const HomeScreen({
    required this.isAuthenticated,
    required this.onAuthenticationNeeded,
    required this.onLogout,
    super.key,
  });

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

    // Check authentication immediately
    _checkAuthentication();

    // Initialize screens
    _initializeScreens();
  }

  void _checkAuthentication() {
    if (!widget.isAuthenticated) {
      // If not authenticated, request authentication
      widget.onAuthenticationNeeded();
    }
  }

  void _initializeScreens() {
    _screens = [
      DashboardScreen(key: _dashboardKey),
      const ExpensesListScreen(),
      BudgetSettingScreen(onBudgetAdded: _refreshData),
      const ReportsScreen(),
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
          // Add a popup menu for recurring items
          PopupMenuButton(
            tooltip: 'Recurring items',
            icon: const Icon(Icons.repeat),
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Text('Recurring Expenses'),
                onTap: () {
                  // We need to use Future.delayed because popupMenuButton
                  // closes the menu before executing onTap
                  Future.delayed(Duration.zero, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RecurringExpenseScreen(),
                      ),
                    ).then((_) => _refreshData());
                  });
                },
              ),
              PopupMenuItem(
                child: const Text('Recurring Budgets'),
                onTap: () {
                  Future.delayed(Duration.zero, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RecurringBudgetScreen(
                          onBudgetAdded: _refreshData,
                        ),
                      ),
                    );
                  });
                },
              ),
              PopupMenuItem(
                child: const Text('Manage Recurring Items'),
                onTap: () {
                  Future.delayed(Duration.zero, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RecurringItemsScreen(),
                      ),
                    ).then((_) => _refreshData());
                  });
                },
              ),
            ],
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
          // Logout button
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: widget.onLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
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
      floatingActionButton: FloatingActionButton(
        // Add a unique hero tag to avoid conflict
        heroTag: 'home_screen_fab',
        onPressed: () async {
          // Navigate to add expense screen and wait for result
          final result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (ctx) => const AddExpenseScreen()),
          );

          // If result is true (expense was added), refresh data
          if (result == true) {
            _refreshData();
          }
        },
        tooltip: 'Add expense',
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
