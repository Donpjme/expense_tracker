import 'package:flutter/material.dart';
import '../models/budget.dart';
import '../models/category.dart'; // Import the Category model
import '../services/database_service.dart';

class BudgetSettingScreen extends StatefulWidget {
  final Function? onBudgetAdded; // Callback function

  const BudgetSettingScreen({
    this.onBudgetAdded,
    super.key,
  });

  @override
  _BudgetSettingScreenState createState() => _BudgetSettingScreenState();
}

class _BudgetSettingScreenState extends State<BudgetSettingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _categoryController = TextEditingController();
  final _budgetLimitController = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  String? _selectedCategory; // Track the selected category
  List<Category> _categories = []; // List of categories
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCategories(); // Load categories when the screen is initialized
  }

  // Load categories from the database
  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final categories = await DatabaseService().getCategories();
      if (!mounted) return; // Check if the widget is still mounted
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading categories: $e')),
      );
    }
  }

  Future<void> _saveBudget() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final newBudget = Budget(
          id: DateTime.now().toString(),
          category: _selectedCategory ?? _categoryController.text,
          budgetLimit: double.parse(_budgetLimitController.text),
          startDate: _startDate,
          endDate: _endDate,
        );

        await DatabaseService().insertBudget(newBudget);

        // Call the callback if it exists
        if (widget.onBudgetAdded != null) {
          widget.onBudgetAdded!();
        }

        if (!mounted) return; // Check if the widget is still mounted

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Budget saved successfully'),
            backgroundColor: Colors.green,
          ),
        );

        setState(() {
          _isLoading = false;
          // Clear form
          _budgetLimitController.clear();
          _selectedCategory = null;
        });

        // Navigate back
        Navigator.of(context).pop(true); // Return true to indicate success
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving budget: $e')),
        );
      }
    }
  }

  Future<void> _selectStartDate(BuildContext context) async {
    // Save context to local variable
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
        // Update end date to be at least start date + 1 day
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 1));
        }
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    // Save context to local variable
    final currentContext = context;

    final pickedDate = await showDatePicker(
      context: currentContext,
      initialDate: _endDate.isBefore(_startDate)
          ? _startDate.add(const Duration(days: 1))
          : _endDate,
      firstDate:
          _startDate.add(const Duration(days: 1)), // Must be after start date
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Budget'),
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
                      TextFormField(
                        controller: _budgetLimitController,
                        decoration: const InputDecoration(
                          labelText: 'Budget Limit',
                          prefixIcon: Icon(Icons.attach_money),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
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
                      Card(
                        child: ListTile(
                          title: Text(
                            'Start Date: ${_startDate.toLocal().toString().split(' ')[0]}',
                          ),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () => _selectStartDate(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: ListTile(
                          title: Text(
                            'End Date: ${_endDate.toLocal().toString().split(' ')[0]}',
                          ),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () => _selectEndDate(context),
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _saveBudget,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Save Budget',
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
    _categoryController.dispose();
    _budgetLimitController.dispose();
    super.dispose();
  }
}
