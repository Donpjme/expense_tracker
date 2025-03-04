import 'package:flutter/material.dart';
import 'package:expense_tracker/services/database_service.dart';
import 'package:expense_tracker/widgets/summary_card.dart';
import 'package:expense_tracker/widgets/budget_progress_card.dart';
import 'package:expense_tracker/widgets/analytics_dashboard_widget.dart';
import 'package:expense_tracker/widgets/expense_insights_widget.dart';
import 'package:expense_tracker/widgets/quick_action_panel.dart';
import 'package:expense_tracker/screens/add_expense_screen.dart';
import 'package:expense_tracker/screens/reports_screen.dart';
import 'package:expense_tracker/screens/recurring_items_screen.dart';
import 'package:expense_tracker/screens/budget_setting_screen.dart'; // Make sure this import is included
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/models/budget.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  List<Expense> _expenses = [];
  List<Budget> _budgets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  // Make this public so it can be called from HomeScreen
  Future<void> loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final expenses = await DatabaseService().getExpenses();
      final budgets = await DatabaseService().getBudgets();

      if (!mounted) return;

      setState(() {
        _expenses = expenses;
        _budgets = budgets;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load data: $e')),
      );
    }
  }

  // Get this month's expenses
  List<Expense> get _thisMonthExpenses {
    final now = DateTime.now();
    return _expenses.where((expense) {
      return expense.date.month == now.month && expense.date.year == now.year;
    }).toList();
  }

  // Calculate total spent this month
  double get _totalSpentThisMonth {
    return _thisMonthExpenses.fold(0.0, (sum, expense) => sum + expense.amount);
  }

  // Calculate total budget for all categories
  double get _totalBudget {
    return _budgets.fold(0.0, (sum, budget) => sum + budget.budgetLimit);
  }

  // Get spending by category for this month
  Map<String, double> get _spendingByCategory {
    final Map<String, double> spending = {};
    for (final expense in _thisMonthExpenses) {
      spending[expense.category] =
          (spending[expense.category] ?? 0) + expense.amount;
    }
    return spending;
  }

  // Get budget by category
  Map<String, double> get _budgetByCategory {
    final Map<String, double> budgets = {};
    for (final budget in _budgets) {
      budgets[budget.category] = budget.budgetLimit;
    }
    return budgets;
  }

  @override
  Widget build(BuildContext context) {
    final spendingByCategory = _spendingByCategory;
    final budgetByCategory = _budgetByCategory;

    // Predefine colors for consistent categories
    final Map<String, Color> categoryColors = {
      'Food': Colors.orange,
      'Transport': Colors.blue,
      'Entertainment': Colors.purple,
      'Utilities': Colors.teal,
      'Health': Colors.red,
      'Education': Colors.green,
      'Shopping': Colors.pink,
      'Miscellaneous': Colors.grey,
    };

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // QuickActionPanel for easily accessing core features
                  QuickActionPanel(
                    onActionCompleted: loadData,
                  ),

                  // Add a "Manage Recurring Items" card
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RecurringItemsScreen(),
                          ),
                        ).then((_) => loadData());
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              child: Icon(
                                Icons.schedule,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Recurring Items',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  Text(
                                    'Manage your recurring expenses and budgets',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Monthly summary cards
                  Row(
                    children: [
                      Expanded(
                        child: SummaryCard(
                          title: 'This Month',
                          value: '\$${_totalSpentThisMonth.toStringAsFixed(2)}',
                          icon: Icons.account_balance_wallet,
                          color: Theme.of(context).colorScheme.primary,
                          onTap: () {
                            // Navigate to reports screen
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ReportsScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SummaryCard(
                          title: 'Total Budget',
                          value: '\$${_totalBudget.toStringAsFixed(2)}',
                          icon: Icons.account_balance_wallet,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Insights Widget - New
                  if (_expenses.isNotEmpty)
                    ExpenseInsightsWidget(
                      expenses: _expenses,
                      budgets: _budgets,
                    ),

                  if (_expenses.isNotEmpty) const SizedBox(height: 24),

                  // Budget Progress Section
                  Text(
                    'Budget Progress',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),

                  const SizedBox(height: 8),

                  // Budget progress cards
                  if (budgetByCategory.isNotEmpty)
                    ...budgetByCategory.keys.map((category) {
                      final budget = budgetByCategory[category] ?? 0;
                      final spent = spendingByCategory[category] ?? 0;
                      final color = categoryColors[category] ??
                          Color((category.hashCode & 0xFFFFFF) | 0xFF000000);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: BudgetProgressCard(
                          category: category,
                          budgetAmount: budget,
                          spentAmount: spent,
                          categoryColor: color,
                        ),
                      );
                    })
                  else
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Text(
                              'No budgets set',
                              style: TextStyle(
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () {
                                // Navigate to budget setting screen - use the imported widget correctly
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => BudgetSettingScreen(
                                      onBudgetAdded: loadData,
                                    ),
                                  ),
                                );
                              },
                              child: const Text('Set Your First Budget'),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Analytics Dashboard Widget - New
                  if (_expenses.isNotEmpty)
                    AnalyticsDashboardWidget(
                      expenses: _expenses,
                      budgets: _budgets,
                      onSeeMorePressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ReportsScreen(),
                          ),
                        );
                      },
                    ),

                  if (_expenses.isNotEmpty) const SizedBox(height: 24),

                  // Recent Expenses Section
                  Text(
                    'Recent Expenses',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),

                  const SizedBox(height: 8),

                  // Recent expenses list
                  if (_expenses.isNotEmpty)
                    ..._expenses.take(5).map((expense) {
                      final color = categoryColors[expense.category] ??
                          Color((expense.category.hashCode & 0xFFFFFF) |
                              0xFF000000);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: color,
                            child: Text(
                              expense.category[0],
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(expense.title),
                          subtitle: Text(
                            '${expense.category} • ${_formatDate(expense.date)}',
                          ),
                          trailing: Text(
                            '\$${expense.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: expense.amount > 100 ? Colors.red : null,
                            ),
                          ),
                        ),
                      );
                    })
                  else
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 48,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No expenses yet',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Colors.grey,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context)
                                    .push(
                                      MaterialPageRoute(
                                        builder: (ctx) =>
                                            const AddExpenseScreen(),
                                      ),
                                    )
                                    .then(
                                        (_) => loadData()); // Refresh on return
                              },
                              child: const Text('Add Your First Expense'),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
      // Add a floating action button with a unique hero tag if needed
      floatingActionButton: _expenses.isEmpty
          ? FloatingActionButton(
              // Add a unique hero tag
              heroTag: 'dashboard_fab',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AddExpenseScreen()),
                ).then((_) => loadData());
              },
              tooltip: 'Add expense',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final expenseDate = DateTime(date.year, date.month, date.day);

    if (expenseDate == today) {
      return 'Today';
    } else if (expenseDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
