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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Regular'),
            Tab(text: 'Recurring'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          // Regular expenses tab
          ExpensesListScreen(),

          // Recurring expenses tab
          RecurringExpenseScreen(),
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
            // Toggle recurring expense form
            // This requires modifying the RecurringExpenseScreen to expose a method
            // For simplicity, we'll just switch to the screen and let the user use the + button
          }
        },
        tooltip: 'Add Expense',
        child: const Icon(Icons.add),
      ),
    );
  }
}
