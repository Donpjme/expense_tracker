import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../models/category.dart'; // Import the Category model
import '../services/database_service.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  _AddExpenseScreenState createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String? _selectedCategory; // Track the selected category
  List<Category> _categories = [];
  bool _isLoading = false; // Track loading state

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await DatabaseService().getCategories();
    if (!mounted) return; // Check if the widget is still mounted
    setState(() {
      _categories = categories;
    });
  }

  Future<void> _saveExpense() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true; // Show loading indicator
      });

      final newExpense = Expense(
        id: DateTime.now().toString(),
        title: _titleController.text,
        amount: double.parse(_amountController.text),
        date: DateTime.now(),
        category: _selectedCategory ?? 'Uncategorized',
      );

      await DatabaseService().insertExpense(newExpense);

      // Check if the budget is exceeded
      final isExceeded =
          await DatabaseService().isBudgetExceeded(newExpense.category);
      print('Is budget exceeded? $isExceeded'); // Debug log

      if (isExceeded) {
        final budget =
            await DatabaseService().getBudgetForCategory(newExpense.category);
        final totalSpent = await DatabaseService()
            .getTotalSpendingForCategory(newExpense.category);
        final exceededBy =
            ((totalSpent - budget.budgetLimit) / budget.budgetLimit) * 100;
        print(
            'Budget Limit: ${budget.budgetLimit}, Total Spent: $totalSpent'); // Debug log

        // Show the notification dialog
        await _showBudgetExceededNotification(newExpense.category, exceededBy);
      }

      setState(() {
        _isLoading = false; // Hide loading indicator
        _titleController.clear(); // Clear the title field
        _amountController.clear(); // Clear the amount field
        _selectedCategory = null; // Reset the selected category
      });

      if (!mounted) return; // Check if the widget is still mounted
      Navigator.of(context).pop(); // Go back to the home screen
    }
  }

  Future<void> _showBudgetExceededNotification(
      String category, double exceededBy) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Budget Exceeded'),
          content: Text(
              'You have exceeded your budget for the $category category by ${exceededBy.toStringAsFixed(2)}%.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Expense'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(labelText: 'Title'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _amountController,
                      decoration: InputDecoration(labelText: 'Amount'),
                      keyboardType: TextInputType.number,
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
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      hint: Text('Select Category'),
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
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _saveExpense,
                      child: Text('Save Expense'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
