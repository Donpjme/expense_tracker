import 'package:flutter/material.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../services/database_service.dart';
import 'package:intl/intl.dart';

class EditBudgetScreen extends StatefulWidget {
  final Budget budget;

  const EditBudgetScreen({
    required this.budget,
    super.key, // Updated to use super parameter syntax
  });

  @override
  State<EditBudgetScreen> createState() =>
      EditBudgetScreenState(); // Renamed to remove underscore
}

class EditBudgetScreenState extends State<EditBudgetScreen> {
  // Renamed to remove underscore
  final _formKey = GlobalKey<FormState>();
  late String _selectedCategory;
  late final TextEditingController _budgetLimitController;
  late DateTime _startDate;
  late DateTime _endDate;
  List<Category> _categories = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.budget.category;
    _budgetLimitController =
        TextEditingController(text: widget.budget.budgetLimit.toString());
    _startDate = widget.budget.startDate;
    _endDate = widget.budget.endDate;
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

  Future<void> _updateBudget() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final updatedBudget = Budget(
          id: widget.budget.id,
          category: _selectedCategory,
          budgetLimit: double.parse(_budgetLimitController.text),
          startDate: _startDate,
          endDate: _endDate,
        );

        // Using the updated method we'll add to DatabaseService
        final db = await DatabaseService().database;
        await db.update(
          'budgets',
          updatedBudget.toMap(),
          where: 'id = ?',
          whereArgs: [updatedBudget.id],
        );

        if (!mounted) return;

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Budget updated successfully'),
            backgroundColor: Colors.green,
          ),
        );

        setState(() {
          _isLoading = false;
        });

        // Return to previous screen with success indicator
        Navigator.of(context).pop(true);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update budget: $e')),
        );
      }
    }
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (!mounted) return;

    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
        // Update end date if it's before start date
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 30));
        }
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate, // Must be after start date
      lastDate: DateTime(2100),
    );

    if (!mounted) return;

    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Budget'),
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
                            _selectedCategory = value!;
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
                            'Start Date: ${DateFormat('MMM d, yyyy').format(_startDate)}',
                          ),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () => _selectStartDate(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: ListTile(
                          title: Text(
                            'End Date: ${DateFormat('MMM d, yyyy').format(_endDate)}',
                          ),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () => _selectEndDate(context),
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _updateBudget,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Update Budget',
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
    _budgetLimitController.dispose();
    super.dispose();
  }
}
