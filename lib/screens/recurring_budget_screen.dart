import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/recurring_budget.dart';
import '../models/category.dart';
import '../services/database_service.dart';

/// Screen for managing recurring budgets
class RecurringBudgetScreen extends StatefulWidget {
  final RecurringBudget? budgetToEdit;

  const RecurringBudgetScreen({
    this.budgetToEdit,
    super.key,
  });

  @override
  _RecurringBudgetScreenState createState() => _RecurringBudgetScreenState();
}

class _RecurringBudgetScreenState extends State<RecurringBudgetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _budgetLimitController = TextEditingController();
  DateTime _startDate = DateTime.now();
  String? _selectedFrequency;
  String? _selectedCategory;
  final List<String> _frequencies = ['Monthly', 'Quarterly', 'Yearly'];
  List<Category> _categories = [];
  List<RecurringBudget> _recurringBudgets = [];
  bool _isLoading = true;
  bool _isAddingNew = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();

    // Check if we're editing an existing budget
    if (widget.budgetToEdit != null) {
      _isEditing = true;
      _budgetLimitController.text = widget.budgetToEdit!.budgetLimit.toString();
      _selectedCategory = widget.budgetToEdit!.category;
      _selectedFrequency = widget.budgetToEdit!.frequency;
      _startDate = widget.budgetToEdit!.startDate;
    }

    _loadData();
  }

  /// Load categories and recurring budgets from the database
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final categories = await DatabaseService().getCategories();
      final recurringBudgets = await DatabaseService().getRecurringBudgets();

      if (!mounted) return;
      setState(() {
        _categories = categories;
        _recurringBudgets = recurringBudgets;
        _isLoading = false;

        // If editing, automatically show the form
        if (_isEditing) {
          _isAddingNew = true;
        }
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

  /// Toggle the add/edit form visibility
  void _toggleAddForm() {
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
    _budgetLimitController.clear();
    _selectedCategory = null;
    _selectedFrequency = null;
    _startDate = DateTime.now();
  }

  /// Save or update a recurring budget
  Future<void> _saveRecurringBudget() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        if (_isEditing) {
          // Update existing recurring budget
          final updatedBudget = RecurringBudget(
            id: widget.budgetToEdit!.id,
            category: _selectedCategory!,
            budgetLimit: double.parse(_budgetLimitController.text),
            startDate: _startDate,
            nextDate: _calculateNextDate(_startDate, _selectedFrequency!),
            frequency: _selectedFrequency!,
          );

          await DatabaseService().updateRecurringBudget(updatedBudget);

          // Show success message
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recurring budget updated successfully'),
              backgroundColor: Colors.green,
            ),
          );

          // If we came from edit mode, return to previous screen
          if (widget.budgetToEdit != null) {
            Navigator.of(context).pop(true);
            return;
          }
        } else {
          // Create new recurring budget
          final newRecurringBudget = RecurringBudget(
            id: DateTime.now().toString(),
            category: _selectedCategory!,
            budgetLimit: double.parse(_budgetLimitController.text),
            startDate: _startDate,
            nextDate: _calculateNextDate(_startDate, _selectedFrequency!),
            frequency: _selectedFrequency!,
          );

          await DatabaseService().insertRecurringBudget(newRecurringBudget);

          // Show success message
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recurring budget saved successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }

        // Reset form
        _resetForm();

        // Reload data
        await _loadData();

        // Toggle form visibility
        setState(() {
          _isAddingNew = false;
          _isEditing = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save recurring budget: $e')),
        );
      }
    }
  }

  /// Calculate the next occurrence date based on frequency
  DateTime _calculateNextDate(DateTime startDate, String frequency) {
    switch (frequency) {
      case 'Monthly':
        return DateTime(startDate.year, startDate.month + 1, startDate.day);
      case 'Quarterly':
        return DateTime(startDate.year, startDate.month + 3, startDate.day);
      case 'Yearly':
        return DateTime(startDate.year + 1, startDate.month, startDate.day);
      default:
        return startDate;
    }
  }

  /// Show date picker and update start date
  Future<void> _selectStartDate(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Recurring Budget' : 'Recurring Budgets'),
        actions: [
          if (!_isEditing) // Only show add/cancel button if not in edit mode
            IconButton(
              icon: Icon(_isAddingNew ? Icons.close : Icons.add),
              onPressed: _toggleAddForm,
              tooltip: _isAddingNew ? 'Cancel' : 'Add New',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_isAddingNew) _buildAddForm(),
                if (!_isAddingNew ||
                    _isEditing) // Only show list when not adding new and not editing
                  Expanded(
                    child: _recurringBudgets.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.account_balance_wallet,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No recurring budgets yet',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color: Colors.grey,
                                      ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _toggleAddForm,
                                  child: const Text(
                                      'Add Your First Recurring Budget'),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _recurringBudgets.length,
                            itemBuilder: (context, index) {
                              final budget = _recurringBudgets[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  title: Text(
                                    budget.category,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    '${budget.frequency} • Next: ${DateFormat('MMM d, yyyy').format(budget.nextDate)}',
                                  ),
                                  trailing: Text(
                                    '\$${budget.budgetLimit.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.1),
                                    child: Icon(
                                      Icons.account_balance_wallet,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  onTap: () => _showBudgetDetails(budget),
                                ),
                              );
                            },
                          ),
                  ),
              ],
            ),
    );
  }

  /// Form for adding or editing a recurring budget
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
              _isEditing ? 'Edit Recurring Budget' : 'Add Recurring Budget',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
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
            TextFormField(
              controller: _budgetLimitController,
              decoration: const InputDecoration(
                labelText: 'Budget Limit',
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a budget limit';
                }
                if (double.tryParse(value) == null) {
                  return 'Please enter a valid number';
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
              onPressed: _saveRecurringBudget,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                _isEditing
                    ? 'Update Recurring Budget'
                    : 'Save Recurring Budget',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            if (_isEditing) // If editing, provide a cancel button
              TextButton(
                onPressed: () {
                  if (widget.budgetToEdit != null) {
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
          ],
        ),
      ),
    );
  }

  /// Show details of a recurring budget
  void _showBudgetDetails(RecurringBudget budget) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recurring Budget Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Category:', budget.category),
            _buildDetailRow(
                'Budget Limit:', '\$${budget.budgetLimit.toStringAsFixed(2)}'),
            _buildDetailRow('Frequency:', budget.frequency),
            _buildDetailRow('Start Date:',
                DateFormat('MMM dd, yyyy').format(budget.startDate)),
            _buildDetailRow('Next Renewal:',
                DateFormat('MMM dd, yyyy').format(budget.nextDate)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () => _editBudget(budget),
            child: const Text('Edit'),
          ),
          TextButton(
            onPressed: () => _deleteBudget(budget),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Edit a recurring budget
  void _editBudget(RecurringBudget budget) {
    Navigator.pop(context); // Close the details dialog

    // If we're on the main recurring budget screen, load data into form
    if (widget.budgetToEdit == null) {
      setState(() {
        _budgetLimitController.text = budget.budgetLimit.toString();
        _selectedCategory = budget.category;
        _selectedFrequency = budget.frequency;
        _startDate = budget.startDate;
        _isEditing = true;
        _isAddingNew = true;
      });
    } else {
      // If we're already in edit mode (which shouldn't happen but just in case)
      Navigator.of(context).pop(); // Return to previous screen

      // Navigate to edit screen for this budget
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => RecurringBudgetScreen(budgetToEdit: budget),
        ),
      );
    }
  }

  /// Format detail rows in the details dialog
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  /// Delete a recurring budget
  Future<void> _deleteBudget(RecurringBudget budget) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recurring Budget'),
        content: const Text(
            'Are you sure you want to delete this recurring budget?'),
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
        // Delete the recurring budget
        await DatabaseService().deleteRecurringBudget(budget.id);

        // Reload data
        await _loadData();

        if (!mounted) return;

        // Close the details dialog
        Navigator.of(context).pop();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recurring budget deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete recurring budget: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _budgetLimitController.dispose();
    super.dispose();
  }
}
