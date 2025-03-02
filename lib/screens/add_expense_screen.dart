import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../services/database_service.dart';
import 'package:logger/logger.dart';
import 'receipt_scanner_screen.dart';
import 'package:intl/intl.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  _AddExpenseScreenState createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String? _selectedCategory;
  List<Category> _categories = [];
  bool _isLoading = false;
  final Logger _logger = Logger();
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final categories = await DatabaseService().getCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
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

  Future<void> _saveExpense() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final newExpense = Expense(
          id: DateTime.now().toString(),
          title: _titleController.text,
          amount: double.parse(_amountController.text),
          date: _selectedDate,
          category: _selectedCategory ?? 'Uncategorized',
        );

        await DatabaseService().insertExpense(newExpense);

        // Check if the budget is exceeded
        final isExceeded =
            await DatabaseService().isBudgetExceeded(newExpense.category);
        _logger.i('Is budget exceeded? $isExceeded');

        if (!mounted) return;

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense added successfully'),
            backgroundColor: Colors.green,
          ),
        );

        if (isExceeded) {
          // Get budget info
          final budget =
              await DatabaseService().getBudgetForCategory(newExpense.category);
          final totalSpent = await DatabaseService()
              .getTotalSpendingForCategory(newExpense.category);
          final exceededBy =
              ((totalSpent - budget.budgetLimit) / budget.budgetLimit) * 100;
          _logger.i(
              'Budget Limit: ${budget.budgetLimit}, Total Spent: $totalSpent');

          // Show the budget exceeded notification
          if (mounted) {
            await _showBudgetExceededNotification(
                newExpense.category, exceededBy);
          }
        }

        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _titleController.clear();
          _amountController.clear();
          _selectedCategory = null;
        });

        // Return to previous screen with success indicator
        Navigator.of(context).pop(true);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save expense: $e')),
        );
      }
    }
  }

  Future<void> _showBudgetExceededNotification(
      String category, double exceededBy) async {
    // Save context to local variable
    final currentContext = context;

    await showDialog(
      context: currentContext,
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

  Future<void> _selectDate(BuildContext context) async {
    // Save context to local variable
    final currentContext = context;

    final DateTime? picked = await showDatePicker(
      context: currentContext,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    // Check if the widget is still mounted before using setState
    if (!mounted) return;

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _scanReceipt() async {
    // Save context to local variable
    final currentContext = context;

    final Map<String, dynamic>? receiptData =
        await Navigator.of(currentContext).push(
      MaterialPageRoute(builder: (ctx) => const ReceiptScannerScreen()),
    );

    // Check if the widget is still mounted before proceeding
    if (!mounted) return;

    if (receiptData != null && receiptData.isNotEmpty) {
      setState(() {
        _titleController.text = receiptData['title'] ?? '';
        _amountController.text = receiptData['amount']?.toString() ?? '';
        _selectedCategory = receiptData['category'];
        if (receiptData['date'] != null) {
          _selectedDate = receiptData['date'];
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt scanned successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense'),
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
                      // Scan receipt button
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.receipt_long),
                          label: const Text('Scan Receipt'),
                          onPressed: _scanReceipt,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.secondary,
                            foregroundColor:
                                Theme.of(context).colorScheme.onSecondary,
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            minimumSize: const Size(
                                double.infinity, 50), // full width button
                          ),
                        ),
                      ),

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

                      // Amount field
                      TextFormField(
                        controller: _amountController,
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          prefixIcon: Icon(Icons.attach_money),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
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

                      // Save button
                      ElevatedButton(
                        onPressed: _saveExpense,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Save Expense',
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

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }
}
