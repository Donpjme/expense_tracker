import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expense_tracker/providers/theme_provider.dart';
import 'package:expense_tracker/screens/dashboard_screen.dart';
import 'package:expense_tracker/screens/expenses_list_screen.dart';
import 'package:expense_tracker/screens/budget_setting_screen.dart';
import 'package:expense_tracker/screens/reports_screen.dart';
import 'package:expense_tracker/screens/add_expense_screen.dart';

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
  }

  void _initializeScreens() {
    _screens = [
      DashboardScreen(key: _dashboardKey),
      // Fixed: Removed the onExpenseDeleted parameter since it's not defined
      ExpensesListScreen(),
      BudgetSettingScreen(onBudgetAdded: _refreshData),
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
