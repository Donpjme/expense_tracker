import 'package:flutter/material.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../services/database_service.dart';
import '../screens/edit_budget_screen.dart';

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
  List<Budget> _budgets = []; // List of existing budgets
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCategories(); // Load categories when the screen is initialized
    _loadBudgets(); // Load existing budgets
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
      });
    } catch (e) {
      if (!mounted) return;
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading categories: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Load existing budgets
  Future<void> _loadBudgets() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final budgets = await DatabaseService().getBudgets();
      if (!mounted) return;
      setState(() {
        _budgets = budgets;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading budgets: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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

        // Reload budgets to show the new one
        _loadBudgets();
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

  void _editBudget(BuildContext context, Budget budget) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditBudgetScreen(budget: budget),
      ),
    );

    // If result is true (budget was updated), refresh data
    if (result == true) {
      _loadBudgets();
      if (widget.onBudgetAdded != null) {
        widget.onBudgetAdded!();
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

  Future<void> _deleteBudget(Budget budget) async {
    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text(
              'Are you sure you want to delete the budget for ${budget.category}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      try {
        final db = await DatabaseService().database;
        await db.delete(
          'budgets',
          where: 'id = ?',
          whereArgs: [budget.id],
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Budget deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Reload budgets and notify parent if needed
        _loadBudgets();
        if (widget.onBudgetAdded != null) {
          widget.onBudgetAdded!();
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete budget: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Form to add new budget
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add New Budget',
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
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _budgetLimitController,
                                decoration: const InputDecoration(
                                  labelText: 'Budget Limit',
                                  prefixIcon: Icon(Icons.attach_money),
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
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
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => _selectStartDate(context),
                                      child: InputDecorator(
                                        decoration: const InputDecoration(
                                          labelText: 'Start Date',
                                          border: OutlineInputBorder(),
                                        ),
                                        child: Text(
                                          '${_startDate.day}/${_startDate.month}/${_startDate.year}',
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
                                          border: OutlineInputBorder(),
                                        ),
                                        child: Text(
                                          '${_endDate.day}/${_endDate.month}/${_endDate.year}',
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: _saveBudget,
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  minimumSize: const Size(double.infinity, 0),
                                ),
                                child: const Text('Save Budget'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // List of existing budgets
                    Text(
                      'Current Budgets',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),

                    if (_budgets.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Center(
                            child: Text(
                              'No budgets set yet',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Colors.grey,
                                  ),
                            ),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _budgets.length,
                        itemBuilder: (context, index) {
                          final budget = _budgets[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(budget.category),
                              subtitle: Text(
                                  '${budget.startDate.day}/${budget.startDate.month}/${budget.startDate.year} - ${budget.endDate.day}/${budget.endDate.month}/${budget.endDate.year}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '\$${budget.budgetLimit.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () =>
                                        _editBudget(context, budget),
                                    tooltip: 'Edit',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () => _deleteBudget(budget),
                                    tooltip: 'Delete',
                                  ),
                                ],
                              ),
                              onTap: () => _editBudget(context, budget),
                            ),
                          );
                        },
                      ),
                  ],
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
