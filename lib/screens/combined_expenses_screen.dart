import 'package:flutter/material.dart';
import 'package:expense_tracker/screens/expenses_list_screen.dart';
import 'package:expense_tracker/screens/recurring_expense_screen.dart';
import 'package:expense_tracker/screens/add_expense_screen.dart';

class CombinedExpensesScreen extends StatefulWidget {
  const CombinedExpensesScreen({super.key});

  @override
  State<CombinedExpensesScreen> createState() => _CombinedExpensesScreenState();
}

class _CombinedExpensesScreenState extends State<CombinedExpensesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Fix: Use generic State<T> instead of specific state class name
  final GlobalKey<State<RecurringExpenseScreen>> _recurringExpenseKey =
      GlobalKey<State<RecurringExpenseScreen>>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Listen to tab changes to update FAB action
    _tabController.addListener(() {
      setState(() {}); // Rebuild to update FAB
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
              Tab(text: 'Regular Expenses'),
              Tab(text: 'Recurring Expenses'),
            ],
            labelColor: Theme.of(context).colorScheme.primary,
            indicatorColor: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Regular expenses tab
          const ExpenseListScreen(),

          // Recurring expenses tab - pass the key to access state
          RecurringExpenseScreen(key: _recurringExpenseKey),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        // Add heroTag to fix conflict
        heroTag: 'combinedExpensesFAB',
        onPressed: () async {
          if (_tabController.index == 0) {
            // Add regular expense
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const AddExpenseScreen(),
              ),
            );
          } else {
            // Toggle recurring expense form if we can access the state
            if (_recurringExpenseKey.currentState != null) {
              // Access the toggleAddForm method - safely with dynamic cast
              final state = _recurringExpenseKey.currentState as dynamic;
              if (state != null && state.toggleAddForm != null) {
                state.toggleAddForm();
              }
            }
          }
        },
        tooltip:
            _tabController.index == 0 ? 'Add Expense' : 'Add Recurring Expense',
        child: const Icon(Icons.add),
      ),
    );
  }
}
