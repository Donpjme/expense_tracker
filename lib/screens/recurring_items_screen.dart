import 'package:flutter/material.dart';
import '../models/recurring_expense.dart';
import '../services/database_service.dart';
import '../screens/recurring_expense_screen.dart';
import '../screens/recurring_budget_screen.dart';
import 'package:intl/intl.dart';

class RecurringItemsScreen extends StatefulWidget {
  const RecurringItemsScreen({super.key});

  @override
  RecurringItemsScreenState createState() => RecurringItemsScreenState();
}

class RecurringItemsScreenState extends State<RecurringItemsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<RecurringExpense> _recurringExpenses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRecurringItems();
  }

  Future<void> _loadRecurringItems() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final recurringExpenses = await DatabaseService().getRecurringExpenses();

      if (!mounted) return;

      setState(() {
        _recurringExpenses = recurringExpenses;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load recurring items: $e')),
      );
    }
  }

  Future<void> _deleteRecurringExpense(String id) async {
    try {
      final db = await DatabaseService().database;
      await db.delete(
        'recurring_expenses',
        where: 'id = ?',
        whereArgs: [id],
      );

      await _loadRecurringItems();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recurring expense deleted'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete recurring expense: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Items'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Expenses'),
            Tab(text: 'Budgets'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              if (_tabController.index == 0) {
                _navigateToAddRecurringExpense();
              } else {
                _navigateToAddRecurringBudget();
              }
            },
            tooltip: 'Add new',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Recurring Expenses Tab
                _buildRecurringExpensesTab(),

                // Recurring Budgets Tab
                _buildRecurringBudgetsTab(),
              ],
            ),
    );
  }

  Widget _buildRecurringExpensesTab() {
    if (_recurringExpenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.repeat,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No recurring expenses yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _navigateToAddRecurringExpense,
              child: const Text('Add Recurring Expense'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRecurringItems,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _recurringExpenses.length,
        itemBuilder: (context, index) {
          final recurringExpense = _recurringExpenses[index];
          final nextDate = DateTime.parse(recurringExpense.nextDate);

          return Dismissible(
            key: Key(recurringExpense.id),
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              child: const Icon(
                Icons.delete,
                color: Colors.white,
              ),
            ),
            direction: DismissDirection.endToStart,
            confirmDismiss: (direction) async {
              return await showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Confirm Deletion'),
                    content: const Text(
                        'Are you sure you want to delete this recurring expense?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Delete'),
                      ),
                    ],
                  );
                },
              );
            },
            onDismissed: (direction) {
              _deleteRecurringExpense(recurringExpense.id);
            },
            child: Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(
                  recurringExpense.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${recurringExpense.category} • ${recurringExpense.frequency}'),
                    Text(
                      'Next date: ${DateFormat('MMM d, yyyy').format(nextDate)}',
                      style: TextStyle(
                        color: nextDate.isBefore(DateTime.now())
                            ? Colors.red
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
                trailing: Text(
                  '\$${recurringExpense.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: recurringExpense.amount > 100
                        ? Colors.red
                        : Colors.green,
                  ),
                ),
                isThreeLine: true,
                onTap: () {
                  // Edit recurring expense (would require creating EditRecurringExpenseScreen)
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecurringBudgetsTab() {
    // Similar to recurring expenses tab but for budgets
    // This could be implemented once you have RecurringBudget model and methods

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.repeat_one,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'No recurring budgets yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey,
                ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _navigateToAddRecurringBudget,
            child: const Text('Add Recurring Budget'),
          ),
        ],
      ),
    );
  }

  void _navigateToAddRecurringExpense() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RecurringExpenseScreen(),
      ),
    );

    if (result == true) {
      await _loadRecurringItems();
    }
  }

  void _navigateToAddRecurringBudget() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecurringBudgetScreen(
          onBudgetAdded: () {
            _loadRecurringItems();
          },
        ),
      ),
    );

    if (result == true) {
      await _loadRecurringItems();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
