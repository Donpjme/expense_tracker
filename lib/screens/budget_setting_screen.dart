import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../services/database_service.dart';
import '../services/currency_service.dart';
import 'package:logger/logger.dart';

/// Screen for setting and managing budgets
class BudgetSettingScreen extends StatefulWidget {
  final Budget? budgetToEdit;
  final Function? onBudgetAdded;
  final bool
      isFullScreen; // Added to track whether this is opened as a full screen

  const BudgetSettingScreen({
    this.budgetToEdit,
    this.onBudgetAdded,
    this.isFullScreen = true, // Default to true for backward compatibility
    super.key,
  });

  @override
  State<BudgetSettingScreen> createState() => _BudgetSettingScreenState();
}

class _BudgetSettingScreenState extends State<BudgetSettingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _categoryController = TextEditingController();
  final _budgetLimitController = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  String? _selectedCategory;
  List<Category> _categories = [];
  List<Budget> _budgets = [];
  bool _isLoading = false;
  bool _isEditing = false;
  bool _isAddingNew = false; // Added to track whether we're adding a new budget
  final Logger _logger = Logger();

  // Currency related fields
  final CurrencyService _currencyService = CurrencyService();
  String _currencyCode = 'USD';
  String _currencySymbol = '\$';

  @override
  void initState() {
    super.initState();

    // Check if we're editing an existing budget
    if (widget.budgetToEdit != null) {
      _isEditing = true;
      _budgetLimitController.text = widget.budgetToEdit!.budgetLimit.toString();
      _selectedCategory = widget.budgetToEdit!.category;
      _startDate = widget.budgetToEdit!.startDate;
      _endDate = widget.budgetToEdit!.endDate;
    }

    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      // Initialize currency service first
      await _currencyService.initialize();
      _currencyCode = await _currencyService.getCurrencyCode();
      _currencySymbol = await _currencyService.getCurrencySymbol();

      // Then load other data
      await loadData();
    } catch (e) {
      _logger.e('Error initializing data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Load categories and budgets from the database - exposed for external access
  Future<void> loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final categories = await DatabaseService().getCategories();
      final budgets = await DatabaseService().getBudgets();

      if (!mounted) return;
      setState(() {
        _categories = categories;
        _budgets = budgets;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  /// Toggle add form visibility
  void toggleAddForm() {
    setState(() {
      _isAddingNew = !_isAddingNew;
      if (!_isAddingNew) {
        _resetForm();
      }
    });
  }

  /// Reset form fields
  void _resetForm() {
    _budgetLimitController.clear();
    _selectedCategory = null;
    _startDate = DateTime.now();
    _endDate = DateTime.now().add(const Duration(days: 30));
  }

  /// Save or update a budget
  Future<void> _saveBudget() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Parse amount from input
        double budgetLimit = double.parse(_budgetLimitController.text);

        if (_isEditing) {
          // Update existing budget
          final updatedBudget = Budget(
            id: widget.budgetToEdit!.id,
            category: _selectedCategory ?? _categoryController.text,
            budgetLimit: budgetLimit,
            startDate: _startDate,
            endDate: _endDate,
            currency: _currencyCode, // Use app's currency code
          );

          await DatabaseService().updateBudget(updatedBudget);

          if (!mounted) return;

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Budget updated successfully'),
              backgroundColor: Colors.green,
            ),
          );

          // Use Future.delayed for consistent behavior
          Future.delayed(const Duration(milliseconds: 100), () {
            if (!mounted) return;

            // Safely navigate back - fixed to use Navigator.pop with mounted check
            if (Navigator.canPop(context)) {
              Navigator.pop(context, true);
            } else {
              // If we can't pop (unusual case), go to home
              Navigator.pushReplacementNamed(context, '/home');
            }
          });
        } else {
          // Create new budget
          final newBudget = Budget(
            id: DateTime.now().toString(),
            category: _selectedCategory ?? _categoryController.text,
            budgetLimit: budgetLimit,
            startDate: _startDate,
            endDate: _endDate,
            currency: _currencyCode, // Use app's currency code
          );

          await DatabaseService().insertBudget(newBudget);

          if (!mounted) return;

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Budget saved successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );

          // Reset form data
          setState(() {
            _isLoading = false;
            _budgetLimitController.clear();
            _selectedCategory = null;

            // If we're in full screen mode, hide the form after saving
            if (widget.isFullScreen) {
              _isAddingNew = false;
            }
          });

          // Reload data
          await loadData();

          // Notify parent if callback exists
          if (widget.onBudgetAdded != null) {
            try {
              widget.onBudgetAdded!();
            } catch (e) {
              _logger.e('Error in budget callback: $e');
            }
          }

          // If we're in full screen mode, pop back to previous screen
          if (widget.isFullScreen && mounted) {
            if (Navigator.canPop(context)) {
              Navigator.pop(context, true);
            }
          }
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving budget: $e')),
          );
        }
      }
    }
  }

  /// Show date picker for start date
  Future<void> _selectStartDate(BuildContext context) async {
    // Store context in local variable
    final currentContext = context;

    final pickedDate = await showDatePicker(
      context: currentContext,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (!mounted) return;

    if (pickedDate != null && pickedDate != _startDate) {
      setState(() {
        _startDate = pickedDate;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 1));
        }
      });
    }
  }

  /// Show date picker for end date
  Future<void> _selectEndDate(BuildContext context) async {
    // Store context in local variable
    final currentContext = context;

    final pickedDate = await showDatePicker(
      context: currentContext,
      initialDate: _endDate.isBefore(_startDate)
          ? _startDate.add(const Duration(days: 1))
          : _endDate,
      firstDate: _startDate.add(const Duration(days: 1)),
      lastDate: DateTime(2100),
    );

    if (!mounted) return;

    if (pickedDate != null && pickedDate != _endDate) {
      setState(() {
        _endDate = pickedDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Build a Scaffold if this is a full screen, otherwise just return the body content
    if (widget.isFullScreen) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit Budget' : 'Manage Budgets'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          actions: [
            if (!_isAddingNew && !_isEditing)
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  setState(() {
                    _isAddingNew = true;
                  });
                },
                tooltip: 'Add Budget',
              ),
          ],
        ),
        body: _buildBody(),
        floatingActionButton: !_isAddingNew && !_isEditing
            ? FloatingActionButton(
                onPressed: () {
                  setState(() {
                    _isAddingNew = true;
                  });
                },
                tooltip: 'Add Budget',
                child: const Icon(Icons.add),
              )
            : null,
      );
    } else {
      // For tab view or other embedded uses
      return _buildBody();
    }
  }

  Widget _buildBody() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Show form if adding new or editing, otherwise show budget list
                  if (_isAddingNew || _isEditing)
                    _buildBudgetForm()
                  else ...[
                    // Add budget button for non-full screen mode
                    if (!widget.isFullScreen)
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _isAddingNew = true;
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add New Budget'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),

                    // Show existing budgets
                    if (_budgets.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Current Budgets',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      ..._budgets.map((budget) => _buildBudgetCard(budget)),
                    ] else ...[
                      const SizedBox(height: 24),
                      Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No budgets set',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Colors.grey,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _isAddingNew = true;
                                });
                              },
                              child: const Text('Set Your First Budget'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          );
  }

  /// Build the budget form with currency display
  Widget _buildBudgetForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isEditing ? 'Edit Budget' : 'Create Budget',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),

          // Category selection
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
          const SizedBox(height: 16),

          // Budget limit with currency display
          TextFormField(
            controller: _budgetLimitController,
            decoration: InputDecoration(
              labelText: 'Budget Limit',
              prefixIcon: Text(
                '  $_currencySymbol ',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 0, minHeight: 0),
              border: const OutlineInputBorder(),
              helperText: 'Currency: $_currencyCode',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
          const SizedBox(height: 16),

          // Date selection
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _selectStartDate(context),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Start Date',
                      prefixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      DateFormat('MMM dd, yyyy').format(_startDate),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: () => _selectEndDate(context),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'End Date',
                      prefixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      DateFormat('MMM dd, yyyy').format(_endDate),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Button row with save and cancel
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveBudget,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _isEditing ? 'Update Budget' : 'Save Budget',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () {
                  if (_isEditing &&
                      widget.budgetToEdit != null &&
                      widget.isFullScreen) {
                    Navigator.of(context).pop();
                  } else {
                    setState(() {
                      _isAddingNew = false;
                      _isEditing = false;
                      _resetForm();
                    });
                  }
                },
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                ),
                child: const Text('Cancel', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Helper function to build a budget card with currency formatting
  Widget _buildBudgetCard(Budget budget) {
    return FutureBuilder<String>(
      future:
          _currencyService.formatCurrency(budget.budgetLimit, budget.currency),
      builder: (context, snapshot) {
        final formattedAmount = snapshot.hasData
            ? snapshot.data!
            : '${budget.currency} ${budget.budgetLimit.toStringAsFixed(2)}';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            children: [
              ListTile(
                title: Text(
                  budget.category,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${DateFormat('MMM d').format(budget.startDate)} - ${DateFormat('MMM d').format(budget.endDate)}',
                ),
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  child: Icon(
                    Icons.account_balance_wallet,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                trailing: Text(
                  formattedAmount,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                onTap: () => _showBudgetDetails(budget),
              ),
              // Action buttons row
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 8, left: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Edit button
                    TextButton.icon(
                      icon: Icon(
                        Icons.edit,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      label: Text(
                        'Edit',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onPressed: () => _editBudget(budget),
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
                      onPressed: () => _deleteBudget(budget),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Show budget details dialog with currency formatting
  void _showBudgetDetails(Budget budget) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return FutureBuilder<String>(
            future: _currencyService.formatCurrency(
                budget.budgetLimit, budget.currency),
            builder: (context, snapshot) {
              final formattedAmount = snapshot.hasData
                  ? snapshot.data!
                  : '${budget.currency} ${budget.budgetLimit.toStringAsFixed(2)}';

              return AlertDialog(
                title: Text(budget.category),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Budget Limit:', formattedAmount),
                    _buildDetailRow('Start Date:',
                        DateFormat('MMM d, yyyy').format(budget.startDate)),
                    _buildDetailRow('End Date:',
                        DateFormat('MMM d, yyyy').format(budget.endDate)),
                    _buildDetailRow('Currency:', budget.currency),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Close'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      _editBudget(budget);
                    },
                    child: const Text('Edit'),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      _deleteBudget(budget);
                    },
                    child: const Text('Delete'),
                  ),
                ],
              );
            });
      },
    );
  }

  /// Format detail rows in dialogs
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

  /// Navigate to edit screen for a budget
  void _editBudget(Budget budget) {
    if (widget.isFullScreen) {
      // If in full screen mode, edit inline
      setState(() {
        _isEditing = true;
        _isAddingNew = true;
        _budgetLimitController.text = budget.budgetLimit.toString();
        _selectedCategory = budget.category;
        _startDate = budget.startDate;
        _endDate = budget.endDate;
      });
    } else {
      // If in tab view, navigate to edit screen
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (context) => BudgetSettingScreen(
                budgetToEdit: budget,
                onBudgetAdded: widget.onBudgetAdded,
              ),
            ),
          )
          .then((_) => loadData()); // Refresh on return
    }
  }

  /// Delete a budget
  Future<void> _deleteBudget(Budget budget) async {
    // Store context in local variable
    final currentContext = context;

    final confirmed = await showDialog<bool>(
      context: currentContext,
      builder: (context) => AlertDialog(
        title: const Text('Delete Budget'),
        content: Text(
            'Are you sure you want to delete the budget for ${budget.category}?'),
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

    if (!mounted) return;

    if (confirmed == true) {
      try {
        await DatabaseService().deleteBudget(budget.id);

        if (!mounted) return;

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Budget deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh budgets list
        loadData();
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete budget: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _budgetLimitController.dispose();
    super.dispose();
  }
}
