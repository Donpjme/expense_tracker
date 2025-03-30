import 'package:flutter/material.dart';
import 'package:expense_tracker/screens/budget_setting_screen.dart';
import 'package:expense_tracker/screens/recurring_budget_screen.dart';

class CombinedBudgetsScreen extends StatefulWidget {
  const CombinedBudgetsScreen({super.key});

  @override
  State<CombinedBudgetsScreen> createState() => _CombinedBudgetsScreenState();
}

class _CombinedBudgetsScreenState extends State<CombinedBudgetsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Keys to access screen states - using State<T> which is the correct type
  final GlobalKey<State<BudgetSettingScreen>> _budgetKey =
      GlobalKey<State<BudgetSettingScreen>>();
  final GlobalKey<State<RecurringBudgetScreen>> _recurringBudgetKey =
      GlobalKey<State<RecurringBudgetScreen>>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Listen to tab changes
    _tabController.addListener(() {
      setState(() {}); // Rebuild to update UI based on selected tab
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Regular Budgets'),
              Tab(text: 'Recurring Budgets'),
            ],
            labelColor: Theme.of(context).colorScheme.primary,
            indicatorColor: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Regular budgets tab
          BudgetSettingScreen(key: _budgetKey, isFullScreen: false),

          // Recurring budgets tab
          RecurringBudgetScreen(key: _recurringBudgetKey),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        // Add heroTag to fix conflict
        heroTag: 'combinedBudgetsFAB',
        onPressed: () {
          if (_tabController.index == 0) {
            // Navigate to budget setting screen
            Navigator.of(context)
                .push(
              MaterialPageRoute(
                builder: (context) => const BudgetSettingScreen(),
              ),
            )
                .then((_) {
              // Refresh data on return
              if (_budgetKey.currentState != null) {
                // Access the loadData method - safely with dynamic cast
                final state = _budgetKey.currentState as dynamic;
                if (state != null && state.loadData != null) {
                  state.loadData();
                }
              }
            });
          } else {
            // Toggle recurring budget form if we can access the state
            if (_recurringBudgetKey.currentState != null) {
              // Access the toggleAddForm method - safely with dynamic cast
              final state = _recurringBudgetKey.currentState as dynamic;
              if (state != null && state.toggleAddForm != null) {
                state.toggleAddForm();
              }
            }
          }
        },
        tooltip:
            _tabController.index == 0 ? 'Add Budget' : 'Add Recurring Budget',
        child: const Icon(Icons.add),
      ),
    );
  }
}
