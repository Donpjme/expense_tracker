import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../services/database_service.dart';
import '../services/currency_service.dart';
import '../widgets/currency_selector.dart';

/// Screen for editing an existing expense
class ExpenseEditScreen extends StatefulWidget {
  final Expense expense;
  final Function? onExpenseUpdated;

  const ExpenseEditScreen({
    required this.expense,
    this.onExpenseUpdated,
    super.key,
  });

  @override
  _ExpenseEditScreenState createState() => _ExpenseEditScreenState();
}

class _ExpenseEditScreenState extends State<ExpenseEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String? _selectedCategory;
  List<Category> _categories = [];
  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();

  // Currency fields
  late CurrencyService _currencyService;
  late String _selectedCurrency;
  bool _isConvertingCurrency = false;
  double? _convertedAmount;
  String _originalCurrency = 'USD';

  @override
  void initState() {
    super.initState();
    _currencyService = CurrencyService();

    // Initialize form with expense data
    _titleController.text = widget.expense.title;
    _amountController.text =
        (widget.expense.originalAmount ?? widget.expense.amount).toString();
    _selectedCategory = widget.expense.category;
    _selectedDate = widget.expense.date;
    _originalCurrency = widget.expense.currency;
    _selectedCurrency = widget.expense.currency;

    _loadCurrencyAndCategories();
  }

  /// Load categories from the database and initialize currency service
  Future<void> _loadCurrencyAndCategories() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Initialize currency service
      await _currencyService.initialize();

      final categories = await DatabaseService().getCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _isLoading = false;
      });

      // Update amount preview if currency is different from default
      if (_selectedCurrency != _currencyService.defaultCurrency) {
        _updateAmountPreview();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load categories: $e')),
      );
    }
  }

  /// Update the expense
  Future<void> _updateExpense() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Parse amount from input
        double originalAmount = double.parse(_amountController.text);
        double amountInDefaultCurrency = originalAmount;

        // Convert to default currency if different from selected
        if (_selectedCurrency != _currencyService.defaultCurrency) {
          amountInDefaultCurrency = await _currencyService.convertCurrency(
              originalAmount,
              _selectedCurrency,
              _currencyService.defaultCurrency);
        }

        final updatedExpense = Expense(
          id: widget.expense.id,
          title: _titleController.text,
          amount: _selectedCurrency == _currencyService.defaultCurrency
              ? originalAmount
              : amountInDefaultCurrency,
          date: _selectedDate,
          category: _selectedCategory ?? 'Uncategorized',
          currency: _selectedCurrency,
          originalAmount: _selectedCurrency != _currencyService.defaultCurrency
              ? originalAmount
              : null,
        );

        await DatabaseService().updateExpense(updatedExpense);

        // Check if the budget is exceeded
        final isExceeded =
            await DatabaseService().isBudgetExceeded(updatedExpense.category);

        if (!mounted) return;

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense updated successfully'),
            backgroundColor: Colors.green,
          ),
        );

        if (isExceeded) {
          // Get budget info
          final budget = await DatabaseService()
              .getBudgetForCategory(updatedExpense.category);
          final totalSpent = await DatabaseService()
              .getTotalSpendingForCategory(updatedExpense.category);
          final exceededBy =
              ((totalSpent - budget.budgetLimit) / budget.budgetLimit) * 100;

          // Show the budget exceeded notification
          if (mounted) {
            await _showBudgetExceededNotification(
                updatedExpense.category, exceededBy);
          }
        }

        // Notify parent if callback exists
        if (widget.onExpenseUpdated != null) {
          try {
            widget.onExpenseUpdated!();
          } catch (e) {
            // Handle callback error
          }
        }

        // Return to previous screen
        if (!mounted) return;
        Navigator.of(context).pop(true);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update expense: $e')),
        );
      }
    }
  }

  /// Show budget exceeded notification
  Future<void> _showBudgetExceededNotification(
      String category, double exceededBy) async {
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Budget Exceeded'),
          content: Text(
              'You have exceeded your budget for the $category category by ${exceededBy.toStringAsFixed(2)}%.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Show date picker
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null && picked != _selectedDate && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  /// Update amount preview when currency changes
  Future<void> _updateAmountPreview() async {
    final amountText = _amountController.text;
    if (amountText.isEmpty) {
      setState(() {
        _convertedAmount = null;
      });
      return;
    }

    try {
      final amount = double.parse(amountText);

      // Only show preview if not in default currency
      if (_selectedCurrency != _currencyService.defaultCurrency) {
        setState(() {
          _isConvertingCurrency = true;
        });

        final converted = await _currencyService.convertCurrency(
            amount, _selectedCurrency, _currencyService.defaultCurrency);

        if (!mounted) return;

        setState(() {
          _convertedAmount = converted;
          _isConvertingCurrency = false;
        });
      } else {
        setState(() {
          _convertedAmount = null;
        });
      }
    } catch (e) {
      setState(() {
        _convertedAmount = null;
        _isConvertingCurrency = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Expense'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Title field
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
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),

                      // Amount field with currency selector
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Amount field
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _amountController,
                              decoration: const InputDecoration(
                                labelText: 'Amount',
                                prefixIcon: Icon(Icons.attach_money),
                                border: OutlineInputBorder(),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter an amount';
                                }
                                if (double.tryParse(value) == null) {
                                  return 'Please enter a valid number';
                                }
                                return null;
                              },
                              textInputAction: TextInputAction.next,
                              onChanged: (_) => _updateAmountPreview(),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Currency selector
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.only(top: 4),
                              height: 62, // Match height with TextFormField
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                ),
                                child: CurrencySelector(
                                  selectedCurrency: _selectedCurrency,
                                  onCurrencyChanged: (currency) {
                                    setState(() {
                                      _selectedCurrency = currency;
                                    });
                                    _updateAmountPreview();
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Currency conversion preview
                      if (_isConvertingCurrency || _convertedAmount != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, left: 8.0),
                          child: _isConvertingCurrency
                              ? const Text(
                                  'Converting...',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey,
                                  ),
                                )
                              : Text(
                                  'Will be saved as: ${_currencyService.formatCurrency(_convertedAmount!, _currencyService.defaultCurrency)} (${_currencyService.defaultCurrency})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey[600],
                                  ),
                                ),
                        ),

                      // Note about original currency if changed
                      if (_originalCurrency != _selectedCurrency)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, left: 8.0),
                          child: Text(
                            'Original currency: $_originalCurrency',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Colors.orange[700],
                            ),
                          ),
                        ),

                      const SizedBox(height: 16),

                      // Category dropdown
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

                      // Date picker
                      InkWell(
                        onTap: () => _selectDate(context),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date',
                            prefixIcon: Icon(Icons.calendar_today),
                            border: OutlineInputBorder(),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('MMM dd, yyyy')
                                    .format(_selectedDate),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const Icon(Icons.arrow_drop_down,
                                  color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Update button
                      ElevatedButton(
                        onPressed: _updateExpense,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Update Expense',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),

                      // Delete button
                      TextButton(
                        onPressed: _confirmDelete,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text(
                          'Delete Expense',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  /// Confirm expense deletion
  Future<void> _confirmDelete() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Expense'),
          content: const Text('Are you sure you want to delete this expense?'),
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
        );
      },
    );

    if (confirmed == true) {
      try {
        await DatabaseService().deleteExpense(widget.expense.id);

        if (!mounted) return;

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Notify parent if callback exists
        if (widget.onExpenseUpdated != null) {
          widget.onExpenseUpdated!();
        }

        // Return to previous screen
        Navigator.of(context).pop(true);
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete expense: $e')),
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
