import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../models/budget.dart'; // Import the Budget model
import '../services/database_service.dart';
import 'add_expense_screen.dart'; // Import the AddExpenseScreen
import 'budget_setting_screen.dart'; // Import the BudgetSettingScreen
import 'category_setting_screen.dart'; // Import the CategorySettingScreen
import 'reports_screen.dart'; // Import the ReportsScreen
import 'recurring_expense_screen.dart'; // Import the RecurringExpenseScreen

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Expense> _expenses = [];
  List<Budget> _budgets = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Load expenses and budgets from the database
  Future<void> _loadData() async {
    final expenses = await DatabaseService().getExpenses();
    final budgets = await DatabaseService().getBudgets();
    setState(() {
      _expenses = expenses;
      _budgets = budgets;
    });
  }

  // Navigate to the AddExpenseScreen and refresh the list after adding a new expense
  void _navigateToAddExpenseScreen(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (ctx) => AddExpenseScreen()),
    );
    // Refresh the list of expenses after returning from the AddExpenseScreen
    _loadData();
  }

  // Navigate to the BudgetSettingScreen and refresh the list after adding a new budget
  void _navigateToBudgetSettingScreen(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (ctx) => BudgetSettingScreen()),
    );
    // Refresh the list of budgets after returning from the BudgetSettingScreen
    _loadData();
  }

  // Navigate to the CategorySettingScreen
  void _navigateToCategorySettingScreen(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (ctx) => CategorySettingScreen()),
    );
    // Refresh the list of categories after returning from the CategorySettingScreen
    _loadData();
  }

  // Navigate to the ReportsScreen
  void _navigateToReportsScreen(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (ctx) => ReportsScreen()),
    );
  }

  void _navigateToRecurringExpenseScreen(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (ctx) => RecurringExpenseScreen()),
    );
  }

  // Calculate budget progress and over-spending percentage
  Map<String, dynamic> _calculateBudgetProgress(
      List<Expense> expenses, Budget budget) {
    final totalSpent = expenses
        .where((expense) => expense.category == budget.category)
        .fold(0.0, (sum, expense) => sum + expense.amount);
    final progress = totalSpent / budget.budgetLimit;
    final exceededBy =
        (totalSpent - budget.budgetLimit) / budget.budgetLimit * 100;
    return {
      'progress': progress,
      'exceededBy': exceededBy,
    };
  }

  // Group expenses by category
  Map<String, List<Expense>> _groupExpensesByCategory(List<Expense> expenses) {
    final Map<String, List<Expense>> groupedExpenses = {};
    for (final expense in expenses) {
      if (groupedExpenses.containsKey(expense.category)) {
        groupedExpenses[expense.category]!.add(expense);
      } else {
        groupedExpenses[expense.category] = [expense];
      }
    }
    return groupedExpenses;
  }

  @override
  Widget build(BuildContext context) {
    final groupedExpenses = _groupExpensesByCategory(_expenses);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart), // Reports icon
            onPressed: () => _navigateToReportsScreen(context),
          ),
          IconButton(
            icon: const Icon(Icons.category),
            onPressed: () => _navigateToCategorySettingScreen(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _navigateToBudgetSettingScreen(context),
          ),
          IconButton(
            icon: const Icon(Icons.repeat), // Recurring expense icon
            onPressed: () => _navigateToRecurringExpenseScreen(context),
          ),
        ],
      ),
      body: _expenses.isEmpty && _budgets.isEmpty
          ? const Center(
              child: Text(
                'No expenses or budgets added yet!',
                style: TextStyle(fontSize: 18),
              ),
            )
          : ListView(
              children: [
                // Display budgets with progress and over-spending percentage
                ..._budgets.map((budget) {
                  final progressData =
                      _calculateBudgetProgress(_expenses, budget);
                  final progress = progressData['progress'];
                  final exceededBy = progressData['exceededBy'];

                  return Card(
                    margin: EdgeInsets.all(8.0),
                    child: ListTile(
                      title: Text(budget.category),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LinearProgressIndicator(value: progress),
                          SizedBox(height: 4),
                          Text(
                            exceededBy > 0
                                ? 'Over budget by ${exceededBy.toStringAsFixed(2)}%'
                                : '${(progress * 100).toStringAsFixed(2)}% of budget used',
                            style: TextStyle(
                              color: exceededBy > 0 ? Colors.red : Colors.green,
                            ),
                          ),
                        ],
                      ),
                      trailing:
                          Text('\$${budget.budgetLimit.toStringAsFixed(2)}'),
                    ),
                  );
                }),
                // Display expenses grouped by category
                ...groupedExpenses.entries.map((entry) {
                  final category = entry.key;
                  final expenses = entry.value;
                  return ExpansionTile(
                    title: Text(category),
                    children: expenses.map((expense) {
                      return ListTile(
                        title: Text(expense.title),
                        subtitle: Text(
                            '\$${expense.amount.toStringAsFixed(2)} - ${expense.category}'),
                        trailing: Text(
                          '${expense.date.day}/${expense.date.month}/${expense.date.year}',
                        ),
                      );
                    }).toList(),
                  );
                }),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddExpenseScreen(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
