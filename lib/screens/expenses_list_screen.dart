import 'package:flutter/material.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/services/database_service.dart';
import 'package:expense_tracker/screens/add_expense_screen.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

class ExpensesListScreen extends StatefulWidget {
  const ExpensesListScreen({super.key});

  @override
  _ExpensesListScreenState createState() => _ExpensesListScreenState();
}

class _ExpensesListScreenState extends State<ExpensesListScreen>
    with AutomaticKeepAliveClientMixin {
  List<Expense> _expenses = [];
  bool _isLoading = true;
  final DatabaseService _databaseService = DatabaseService();
  final Logger _logger = Logger();

  // Add this to maintain state when switching tabs
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // This helps refresh when returning to this screen
    _loadExpenses();
  }

  // Add this to ensure we reload when this tab becomes visible again
  @override
  void activate() {
    super.activate();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Add logger statement for debugging
      _logger.i('Loading expenses from database');
      final expenses = await _databaseService.getExpenses();
      _logger.i('Loaded ${expenses.length} expenses from database');

      if (!mounted) return;

      setState(() {
        _expenses = expenses;
        // Sort expenses by date (most recent first)
        _expenses.sort((a, b) => b.date.compareTo(a.date));
        _isLoading = false;
      });
    } catch (e) {
      _logger.e('Error loading expenses: $e');
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load expenses: $e')),
        );
      }
    }
  }

  // Helper method to format date
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
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  // Helper to format currency
  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 2,
    );

    if (amount >= 10000) {
      return NumberFormat.compactCurrency(
        symbol: '\$',
        decimalDigits: 1,
      ).format(amount);
    }

    return formatter.format(amount);
  }

  // Method to handle expense deletion
  Future<void> _handleDeleteExpense(String id, int index) async {
    // First update UI
    final deletedExpense = _expenses[index];
    setState(() {
      _expenses.removeAt(index);
    });

    // Show snackbar with undo option
    if (mounted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Expense deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              // Restore the expense in UI
              setState(() {
                _expenses.insert(index, deletedExpense);
              });
              // Sort expenses again
              setState(() {
                _expenses.sort((a, b) => b.date.compareTo(a.date));
              });
            },
          ),
        ),
      );
    }

    // Then try to update database
    try {
      // Use direct SQLite deletion instead of calling a method that doesn't exist yet
      final db = await _databaseService.database;
      await db.delete(
        'expenses',
        where: 'id = ?',
        whereArgs: [id],
      );
      _logger.i('Expense deleted: $id');
    } catch (e) {
      _logger.e('Error deleting expense: $e');
      // If deletion fails, restore the expense in UI
      if (mounted) {
        setState(() {
          _expenses.insert(index, deletedExpense);
          // Sort expenses again
          _expenses.sort((a, b) => b.date.compareTo(a.date));
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete expense: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadExpenses,
              child: _expenses.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No expenses yet',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: Colors.grey,
                                ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () async {
                              // Navigate to add expense screen and wait for result
                              final result = await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (ctx) => const AddExpenseScreen(),
                                ),
                              );

                              // Refresh expenses list if expense was added
                              if (result == true) {
                                _loadExpenses();
                              }
                            },
                            child: const Text('Add Your First Expense'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _expenses.length,
                      itemBuilder: (context, index) {
                        final expense = _expenses[index];
                        return Dismissible(
                          key: Key(expense.id),
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
                                      'Are you sure you want to delete this expense?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                          onDismissed: (direction) {
                            // Delete the expense
                            _handleDeleteExpense(expense.id, index);
                          },
                          child: Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Text(
                                expense.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${expense.category} • ${_formatDate(expense.date)}',
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Text(
                                _formatCurrency(expense.amount),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: expense.amount > 100
                                      ? Colors.red
                                      : Colors.green,
                                ),
                              ),
                              onTap: () {
                                // Show expense details in a bottom sheet
                                _showExpenseDetails(context, expense);
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  void _showExpenseDetails(BuildContext context, Expense expense) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                expense.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Amount:', _formatCurrency(expense.amount)),
              _buildDetailRow('Category:', expense.category),
              _buildDetailRow(
                  'Date:', DateFormat('MMMM d, yyyy').format(expense.date)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete Expense'),
                  onPressed: () {
                    Navigator.pop(context);
                    // Delete the expense
                    _confirmDelete(context, expense);
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure you want to delete this expense?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final index = _expenses.indexWhere((e) => e.id == expense.id);
      if (index != -1) {
        _handleDeleteExpense(expense.id, index);
      }
    }
  }
}
