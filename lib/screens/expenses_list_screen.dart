import 'package:flutter/material.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/services/database_service.dart';
import 'package:expense_tracker/screens/add_expense_screen.dart';
import 'package:expense_tracker/screens/expense_edit_screen.dart';
import 'package:expense_tracker/widgets/expense_list_item.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

class ExpenseListScreen extends StatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  _ExpenseListScreenState createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen>
    with AutomaticKeepAliveClientMixin {
  List<Expense> _expenses = [];
  bool _isLoading = false;
  final DatabaseService _databaseService = DatabaseService();
  final Logger _logger = Logger();

  // Create a key for the RefreshIndicator to programmatically trigger refresh
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  // Keep state when switching tabs
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Initial load
    _loadExpenses();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  // Called when returning to this tab
  @override
  void activate() {
    super.activate();
    // Refresh data when tab is activated
    _refreshIndicatorKey.currentState?.show();
  }

  // Simplified method to load expenses with proper state management
  Future<void> _loadExpenses() async {
    // Don't set state if the widget is already loading
    if (_isLoading) return;

    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
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

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load expenses: $e')),
        );
      }
    }
  }

  // Method to handle expense deletion
  Future<void> _handleDeleteExpense(String id, int index) async {
    // First update UI optimistically
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
                // Sort expenses again
                _expenses.sort((a, b) => b.date.compareTo(a.date));
              });
            },
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }

    // Then try to update database
    try {
      await _databaseService.deleteExpense(id);
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
      body: RefreshIndicator(
        key: _refreshIndicatorKey,
        onRefresh: _loadExpenses,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _expenses.isEmpty
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
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.grey,
                                  ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _navigateToAddScreen,
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
                      return ExpenseListItem(
                        expense: expense,
                        onTap: () => _showExpenseDetails(context, expense),
                        onEdit: () => _navigateToEditScreen(expense),
                        onDelete: () => _confirmDelete(context, expense),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'expensesListFAB',
        onPressed: _navigateToAddScreen,
        tooltip: 'Add Expense',
        child: const Icon(Icons.add),
      ),
    );
  }

  // Navigate to add expense screen
  Future<void> _navigateToAddScreen() async {
    final dynamic result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddExpenseScreen(),
      ),
    );

    // Refresh expenses list if expense was added
    if (result == true) {
      _loadExpenses();
    }
  }

  // Navigate to edit screen
  Future<void> _navigateToEditScreen(Expense expense) async {
    final dynamic result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ExpenseEditScreen(
          expense: expense,
          onExpenseUpdated: () {}, // Empty callback since we'll refresh anyway
        ),
      ),
    );

    // Refresh expenses list if expense was updated
    if (result == true) {
      _loadExpenses();
    }
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
              _buildDetailRow(
                'Amount:',
                '${expense.currency} ${expense.amount.toStringAsFixed(2)}',
              ),
              _buildDetailRow('Category:', expense.category),
              _buildDetailRow(
                  'Date:', DateFormat('MMMM d, yyyy').format(expense.date)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                      onPressed: () {
                        Navigator.pop(context); // Close the bottom sheet
                        _navigateToEditScreen(expense);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete'),
                      onPressed: () {
                        Navigator.pop(context);
                        _confirmDelete(context, expense);
                      },
                    ),
                  ),
                ],
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
