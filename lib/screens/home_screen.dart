import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expense_tracker/providers/theme_provider.dart';
import 'package:expense_tracker/screens/dashboard_screen.dart';
import 'package:expense_tracker/screens/expenses_list_screen.dart';
import 'package:expense_tracker/screens/budget_setting_screen.dart';
import 'package:expense_tracker/screens/reports_screen.dart';
import 'package:expense_tracker/screens/add_expense_screen.dart';
import 'package:expense_tracker/services/local_auth_service.dart';
import 'package:logger/logger.dart';

class HomeScreen extends StatefulWidget {
  final bool isAuthenticated;
  final Function() onAuthenticationNeeded;
  final Function() onLogout;

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
  bool _isAuthenticatedLocally;
  final LocalAuthService _authService = LocalAuthService();
  final Logger _logger = Logger();

  // Keys to access screen states
  final GlobalKey<DashboardScreenState> _dashboardKey =
      GlobalKey<DashboardScreenState>();

  _HomeScreenState() : _isAuthenticatedLocally = false;

  @override
  void initState() {
    super.initState();
    _isAuthenticatedLocally = widget.isAuthenticated;
    _logger
        .i("HomeScreen initialized, authenticated: $_isAuthenticatedLocally");

    // If not authenticated, request authentication immediately
    if (!_isAuthenticatedLocally) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _logger.i("Requesting authentication after init");
        _checkAuthentication();
      });
    }
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update local authentication state when widget property changes
    if (widget.isAuthenticated != oldWidget.isAuthenticated) {
      _logger.i(
          "HomeScreen authentication state updated from ${oldWidget.isAuthenticated} to ${widget.isAuthenticated}");
      setState(() {
        _isAuthenticatedLocally = widget.isAuthenticated;
      });

      // If authentication changed to false, prompt for authentication
      if (!_isAuthenticatedLocally) {
        _checkAuthentication();
      }
    }
  }

  // Check authentication and request if needed
  void _checkAuthentication() {
    _logger
        .i("Checking authentication, current state: $_isAuthenticatedLocally");
    if (!_isAuthenticatedLocally) {
      _logger.i("Not authenticated, requesting authentication");
      widget.onAuthenticationNeeded();
    }
  }

  // Function to refresh data
  void _refreshData() {
    _logger.i("Refreshing data");
    if (_dashboardKey.currentState != null) {
      _dashboardKey.currentState!.loadData();
    }

    setState(() {
      // This forces the current screen to rebuild
    });
  }

  // Handle logout
  Future<void> _handleLogout() async {
    _logger.i("Logout requested");
    final bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm Logout'),
            content: const Text(
                'Are you sure you want to log out? You will need to enter your PIN to access your data again.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Logout'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      _logger.i("Logout confirmed, logging out");
      await _authService.logOut();
      setState(() {
        _isAuthenticatedLocally = false;
      });
      widget.onLogout();
    } else {
      _logger.i("Logout cancelled");
    }
  }

  // Get the appropriate screens based on authentication status
  List<Widget> _getScreens() {
    if (_isAuthenticatedLocally) {
      _logger.i("Getting authenticated screens");
      return [
        DashboardScreen(key: _dashboardKey),
        const ExpensesListScreen(),
        BudgetSettingScreen(onBudgetAdded: _refreshData),
        const ReportsScreen(),
      ];
    } else {
      _logger.i("Getting locked screens");
      // Show placeholder screens with lock overlays if not authenticated
      return [
        _buildLockedScreen(
          icon: Icons.dashboard_outlined,
          message: 'Dashboard is locked',
        ),
        _buildLockedScreen(
          icon: Icons.list_outlined,
          message: 'Expenses are locked',
        ),
        _buildLockedScreen(
          icon: Icons.account_balance_wallet_outlined,
          message: 'Budget settings are locked',
        ),
        _buildLockedScreen(
          icon: Icons.bar_chart_outlined,
          message: 'Reports are locked',
        ),
      ];
    }
  }

  // Build a locked screen placeholder
  Widget _buildLockedScreen({
    required IconData icon,
    required String message,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.lock,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Icon(
            icon,
            size: 48,
            color: Colors.grey.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              _logger.i("Unlock button pressed, requesting authentication");
              widget.onAuthenticationNeeded();
            },
            icon: const Icon(Icons.lock_open),
            label: const Text('Unlock'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = _getScreens();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isAuthenticatedLocally ? _refreshData : null,
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
          // Logout button with clear icon
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          // If not authenticated and trying to change tabs, request authentication
          if (!_isAuthenticatedLocally) {
            _logger.i(
                "Tab change attempted while locked, requesting authentication");
            widget.onAuthenticationNeeded();
            return;
          }

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
        onPressed: _isAuthenticatedLocally
            ? () async {
                // Navigate to add expense screen and wait for result
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(builder: (ctx) => const AddExpenseScreen()),
                );

                // If result is true (expense was added), refresh data
                if (result == true) {
                  _refreshData();
                }
              }
            : () {
                _logger.i(
                    "Add expense button pressed while locked, requesting authentication");
                widget.onAuthenticationNeeded();
              },
        tooltip: 'Add expense',
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
