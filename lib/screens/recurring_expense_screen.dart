import 'package:flutter/material.dart';
import '../models/recurring_expense.dart';
import '../models/category.dart'; // Import the Category model
import '../services/database_service.dart';

class RecurringExpenseScreen extends StatefulWidget {
  const RecurringExpenseScreen({super.key});

  @override
  _RecurringExpenseScreenState createState() => _RecurringExpenseScreenState();
}

class _RecurringExpenseScreenState extends State<RecurringExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _startDate = DateTime.now();
  String? _selectedFrequency; // Track the selected frequency
  String? _selectedCategory; // Track the selected category
  final List<String> _frequencies = [
    'Daily',
    'Weekly',
    'Monthly'
  ]; // Frequency options
  List<Category> _categories = []; // List of categories

  @override
  void initState() {
    super.initState();
    _loadCategories(); // Load categories when the screen is initialized
  }

  // Load categories from the database
  Future<void> _loadCategories() async {
    final categories = await DatabaseService().getCategories();
    if (!mounted) return; // Check if the widget is still mounted
    setState(() {
      _categories = categories;
    });
  }

  Future<void> _saveRecurringExpense() async {
    if (_formKey.currentState!.validate()) {
      final newRecurringExpense = RecurringExpense(
        id: DateTime.now().toString(),
        title: _titleController.text,
        amount: double.parse(_amountController.text),
        category: _selectedCategory!, // Use the selected category
        startDate: _startDate,
        nextDate: _calculateNextDate(_startDate, _selectedFrequency!),
        frequency: _selectedFrequency!,
      );

      await DatabaseService().insertRecurringExpense(newRecurringExpense);
      if (!mounted) return; // Check if the widget is still mounted
      Navigator.of(context).pop(); // Go back to the home screen
    }
  }

  DateTime _calculateNextDate(DateTime startDate, String frequency) {
    switch (frequency) {
      case 'Daily':
        return startDate.add(Duration(days: 1));
      case 'Weekly':
        return startDate.add(Duration(days: 7));
      case 'Monthly':
        return DateTime(startDate.year, startDate.month + 1, startDate.day);
      default:
        return startDate;
    }
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null && pickedDate != _startDate) {
      setState(() {
        _startDate = pickedDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Recurring Expense'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
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
              DropdownButtonFormField<String>(
                value: _selectedFrequency,
                hint: Text('Select Frequency'),
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
              ListTile(
                title: Text(
                    'Start Date: ${_startDate.toLocal().toString().split(' ')[0]}'),
                trailing: Icon(Icons.calendar_today),
                onTap: () => _selectStartDate(context),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveRecurringExpense,
                child: Text('Save Recurring Expense'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
