import 'package:flutter/material.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../services/database_service.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

class RecurringBudgetScreen extends StatefulWidget {
  final Function? onBudgetAdded; // Callback function when budget is added

  const RecurringBudgetScreen({
    this.onBudgetAdded,
    super.key,
  });

  @override
  RecurringBudgetScreenState createState() => RecurringBudgetScreenState();
}

class RecurringBudgetScreenState extends State<RecurringBudgetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _budgetLimitController = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  String? _selectedCategory;
  String? _selectedFrequency;
  List<Category> _categories = [];
  bool _isLoading = false;
  final Logger _logger = Logger();

  // Options for recurring frequency
  final List<String> _frequencies = [
    'Weekly',
    'Monthly',
    'Quarterly',
    'Yearly'
  ];

  @override
  void initState() {
    super.initState();
    _loadCategories();
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
      _logger.e('Error loading categories', error: e);
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

  Future<void> _saveRecurringBudget() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Create a budget entry
        final newBudget = Budget(
          id: DateTime.now().toString(),
          category: _selectedCategory!,
          budgetLimit: double.parse(_budgetLimitController.text),
          startDate: _startDate,
          endDate: _endDate,
        );

        await DatabaseService().insertBudget(newBudget);

        // Log the creation of a recurring budget
        _logger.i('Recurring budget created: ${newBudget.category} '
            'with limit: \$${newBudget.budgetLimit.toStringAsFixed(2)}');

        // Call the callback if it exists
        if (widget.onBudgetAdded != null) {
          widget.onBudgetAdded!();
        }

        if (!mounted) return; // Check if the widget is still mounted

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recurring budget saved successfully'),
            backgroundColor: Colors.green,
          ),
        );

        setState(() {
          _isLoading = false;
          // Clear form
          _budgetLimitController.clear();
          _selectedCategory = null;
          _selectedFrequency = null;
        });

        // Navigate back
        Navigator.of(context).pop(true); // Return true to indicate success
      } catch (e) {
        _logger.e('Error saving budget', error: e);
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

  // Calculate end date based on frequency and start date
  void _updateEndDate() {
    if (_selectedFrequency == null) return;

    setState(() {
      switch (_selectedFrequency) {
        case 'Weekly':
          _endDate = _startDate.add(const Duration(days: 7));
          break;
        case 'Monthly':
          _endDate =
              DateTime(_startDate.year, _startDate.month + 1, _startDate.day);
          break;
        case 'Quarterly':
          _endDate =
              DateTime(_startDate.year, _startDate.month + 3, _startDate.day);
          break;
        case 'Yearly':
          _endDate =
              DateTime(_startDate.year + 1, _startDate.month, _startDate.day);
          break;
        default:
          _endDate = _startDate.add(const Duration(days: 30));
      }
    });
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
        // Update end date based on the frequency
        _updateEndDate();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Recurring Budget'),
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

                      // Budget limit field
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

                      // Frequency dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedFrequency,
                        decoration: const InputDecoration(
                          labelText: 'Budget Frequency',
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
                            _updateEndDate();
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a frequency';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Start date selector
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

                      // End date display (calculated automatically)
                      Card(
                        child: ListTile(
                          title: Text(
                            'End of First Period: ${DateFormat('MMM d, yyyy').format(_endDate)}',
                          ),
                          subtitle:
                              Text('Next period will start automatically'),
                          trailing: const Icon(Icons.date_range),
                        ),
                      ),

                      // Extra info card
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      size: 20),
                                  const SizedBox(width: 8),
                                  Text('About Recurring Budgets',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Recurring budgets will automatically reset at the end of each period. Your spending data will still be tracked, but the budget limit will reset to help you maintain consistent budgeting.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _saveRecurringBudget,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Save Recurring Budget',
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
