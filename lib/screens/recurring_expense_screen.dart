import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/recurring_expense.dart';
import '../models/category.dart';
import '../services/database_service.dart';
import 'package:logger/logger.dart';

/// Screen for managing recurring expenses
class RecurringExpenseScreen extends StatefulWidget {
  final RecurringExpense? expenseToEdit;

  const RecurringExpenseScreen({
    this.expenseToEdit,
    super.key,
  });

  @override
  RecurringExpenseScreenState createState() => RecurringExpenseScreenState();
}

class RecurringExpenseScreenState extends State<RecurringExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _logger = Logger();
  DateTime _startDate = DateTime.now();
  String? _selectedFrequency = 'Monthly';
  String? _selectedCategory;
  final List<String> _frequencies = ['Daily', 'Weekly', 'Monthly'];
  List<Category> _categories = [];
  List<RecurringExpense> _recurringExpenses = [];
  bool _isLoading = true;
  bool _isAddingNew = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();

    // Check if we're editing an existing expense
    if (widget.expenseToEdit != null) {
      _isEditing = true;
      _titleController.text = widget.expenseToEdit!.title;
      _amountController.text = widget.expenseToEdit!.amount.toString();
      _selectedCategory = widget.expenseToEdit!.category;
      _selectedFrequency = widget.expenseToEdit!.frequency;
      _startDate = widget.expenseToEdit!.startDate;
    }

    loadData();
  }

  /// Load categories and recurring expenses from the database
  Future<void> loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final categories = await DatabaseService().getCategories();
      final recurringExpenses = await DatabaseService().getRecurringExpenses();

      if (!mounted) return;
      setState(() {
        _categories = categories;
        _recurringExpenses = recurringExpenses;
        _isLoading = false;

        // If editing, automatically show the form
        if (_isEditing) {
          _isAddingNew = true;
        }
      });
    } catch (e) {
      _logger.e('Error loading data: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: $e')),
        );
      }
    }
  }

  /// Toggle the add/edit form visibility - Exposed for external access
  void toggleAddForm() {
    setState(() {
      _isAddingNew = !_isAddingNew;
      if (!_isAddingNew && !_isEditing) {
        // Reset form when canceling (only if not editing)
        _resetForm();
      }
    });
  }

  /// Reset form fields
  void _resetForm() {
    _titleController.clear();
    _amountController.clear();
    _selectedCategory = null;
    _selectedFrequency = 'Monthly';
    _startDate = DateTime.now();
  }

  // Rest of the methods remain the same...

  /// Save or update a recurring expense
  Future<void> _saveRecurringExpense() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        if (_isEditing && widget.expenseToEdit != null) {
          // Update existing recurring expense
          final updatedExpense = RecurringExpense(
            id: widget.expenseToEdit!.id,
            title: _titleController.text,
            amount: double.parse(_amountController.text),
            category: _selectedCategory!,
            startDate: _startDate,
            nextDate: _calculateNextDate(_startDate, _selectedFrequency!),
            frequency: _selectedFrequency!,
            isActive: true, // Set as active
          );

          await DatabaseService().updateRecurringExpense(updatedExpense);

          // Show success message
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recurring expense updated successfully'),
              backgroundColor: Colors.green,
            ),
          );

          // If we came from edit mode, return to previous screen
          if (widget.expenseToEdit != null) {
            Navigator.of(context).pop(true);
            return;
          }
        } else {
          // Create new recurring expense
          final newRecurringExpense = RecurringExpense(
            id: DateTime.now().toString(),
            title: _titleController.text,
            amount: double.parse(_amountController.text),
            category: _selectedCategory!,
            startDate: _startDate,
            nextDate: _calculateNextDate(_startDate, _selectedFrequency!),
            frequency: _selectedFrequency!,
            isActive: true, // Set as active by default
          );

          await DatabaseService().insertRecurringExpense(newRecurringExpense);

          // Show success message
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recurring expense added successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }

        // Reset form
        _resetForm();

        // Reload data
        await loadData();

        // Toggle form visibility
        setState(() {
          _isAddingNew = false;
          _isEditing = false;
          _isLoading = false; // Make sure to set loading state back to false
        });
      } catch (e) {
        _logger.e('Error saving recurring expense: $e');
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save recurring expense: $e')),
          );
        }
      }
    }
  }

  /// Calculate the next occurrence date based on frequency
  DateTime _calculateNextDate(DateTime startDate, String frequency) {
    switch (frequency) {
      case 'Daily':
        return startDate.add(const Duration(days: 1));
      case 'Weekly':
        return startDate.add(const Duration(days: 7));
      case 'Monthly':
        return DateTime(startDate.year, startDate.month + 1, startDate.day);
      default:
        return startDate.add(const Duration(days: 30)); // Default to monthly
    }
  }

  /// Show date picker and update start date
  Future<void> _selectStartDate(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null && pickedDate != _startDate && mounted) {
      setState(() {
        _startDate = pickedDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // We'll remove the AppBar since this will be used in a tab view
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              if (_isAddingNew) _buildAddForm(),
              if (!_isAddingNew ||
                  _isEditing) // Only show list when not adding new and not editing
                Expanded(
                  child: _recurringExpenses.isEmpty
                      ? Center(
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
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: Colors.grey,
                                    ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: toggleAddForm,
                                child: const Text(
                                    'Add Your First Recurring Expense'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _recurringExpenses.length,
                          itemBuilder: (context, index) {
                            final expense = _recurringExpenses[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                children: [
                                  ListTile(
                                    title: Text(
                                      expense.title,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text(
                                      '${expense.frequency} • Next: ${DateFormat('MMM d, yyyy').format(expense.nextDate)}',
                                    ),
                                    trailing: Text(
                                      '\$${expense.amount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: expense.amount > 100
                                            ? Colors.red
                                            : Colors.green,
                                      ),
                                    ),
                                    leading: CircleAvatar(
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withOpacity(0.1),
                                      child: Icon(
                                        Icons.repeat,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                  ),
                                  // Action buttons
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        right: 8, bottom: 8, left: 8),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        // Edit button
                                        TextButton.icon(
                                          icon: Icon(
                                            Icons.edit,
                                            size: 20,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                          label: Text(
                                            'Edit',
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                          ),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                          ),
                                          onPressed: () =>
                                              _editExpense(expense),
                                        ),
                                        const SizedBox(width: 8),
                                        // Delete button
                                        TextButton.icon(
                                          icon: const Icon(
                                            Icons.delete,
                                            size: 20,
                                            color: Colors.red,
                                          ),
                                          label: const Text(
                                            'Delete',
                                            style: TextStyle(
                                              color: Colors.red,
                                            ),
                                          ),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                          ),
                                          onPressed: () =>
                                              _deleteExpense(expense),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
            ],
          );
  }

  // The remaining methods from the original file would go here...
  // I'm omitting them for brevity, but they should be included as-is

  /// Form for adding or editing a recurring expense
  Widget _buildAddForm() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing ? 'Edit Recurring Expense' : 'Add Recurring Expense',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                prefixIcon: Icon(Icons.title),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an amount';
                }
                if (double.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.category),
                border: OutlineInputBorder(),
              ),
              hint: const Text('Select Category'),
              items: _categories.map((category) {
                return DropdownMenuItem(
                  value: category.name,
                  child: Text(category.name),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a category';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedFrequency,
              decoration: const InputDecoration(
                labelText: 'Frequency',
                prefixIcon: Icon(Icons.repeat),
                border: OutlineInputBorder(),
              ),
              hint: const Text('Select Frequency'),
              items: _frequencies.map((frequency) {
                return DropdownMenuItem(
                  value: frequency,
                  child: Text(frequency),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedFrequency = value;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a frequency';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _selectStartDate(context),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Start Date',
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('MMM dd, yyyy').format(_startDate),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveRecurringExpense,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                _isEditing
                    ? 'Update Recurring Expense'
                    : 'Save Recurring Expense',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            if (_isEditing) // If editing, provide a cancel button
              TextButton(
                onPressed: () {
                  if (widget.expenseToEdit != null) {
                    Navigator.of(context).pop();
                  } else {
                    setState(() {
                      _isAddingNew = false;
                      _isEditing = false;
                      _resetForm();
                    });
                  }
                },
                child: const Text('Cancel'),
              ),
            // Add a cancel button when adding new (not editing)
            if (!_isEditing && _isAddingNew)
              TextButton(
                onPressed: toggleAddForm,
                child: const Text('Cancel'),
              ),
          ],
        ),
      ),
    );
  }

  /// Edit a recurring expense
  void _editExpense(RecurringExpense expense) {
    // If we're on the main recurring expense screen, load data into form
    if (widget.expenseToEdit == null) {
      setState(() {
        _titleController.text = expense.title;
        _amountController.text = expense.amount.toString();
        _selectedCategory = expense.category;
        _selectedFrequency = expense.frequency;
        _startDate = expense.startDate;
        _isEditing = true;
        _isAddingNew = true;
      });
    } else {
      // If we're already in edit mode (which shouldn't happen but just in case)
      Navigator.of(context).pop(); // Return to previous screen

      // Navigate to edit screen for this expense
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => RecurringExpenseScreen(expenseToEdit: expense),
        ),
      );
    }
  }

  /// Delete a recurring expense
  Future<void> _deleteExpense(RecurringExpense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recurring Expense'),
        content: const Text(
            'Are you sure you want to delete this recurring expense?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Delete the recurring expense
        await DatabaseService().deleteRecurringExpense(expense.id);

        // Reload data
        await loadData();

        if (!mounted) return;

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recurring expense deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        _logger.e('Error deleting recurring expense: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete recurring expense: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }
}
