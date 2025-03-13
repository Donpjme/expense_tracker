import 'package:flutter/material.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../services/database_service.dart';

class BudgetSettingScreen extends StatefulWidget {
  final Function? onBudgetAdded;

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
  String? _selectedCategory;
  List<Category> _categories = [];
  bool _isLoading = false;

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

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading categories: $e')),
        );
      }
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

        if (!mounted) return;

        // Show success message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Budget saved successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );
        }

        // Reset form data
        setState(() {
          _isLoading = false;
          _budgetLimitController.clear();
          _selectedCategory = null;
        });

        // Use Future.delayed to ensure UI updates before navigating
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!mounted) return;

          // Notify parent if callback exists
          if (widget.onBudgetAdded != null) {
            try {
              widget.onBudgetAdded!();
            } catch (e) {
              print('Error in budget callback: $e');
            }
          }

          // Replace with a clean navigation to home
          if (context.mounted) {
            // Navigate to home screen directly rather than popping
            Navigator.of(context)
                .pushNamedAndRemoveUntil('/home', (route) => false);
          }
        });
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

  Future<void> _selectStartDate(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
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

  Future<void> _selectEndDate(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
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
    return WillPopScope(
      // Handle back button press gracefully
      onWillPop: () async {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/home', (route) => false);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Set Budget'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/home', (route) => false);
            },
          ),
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
