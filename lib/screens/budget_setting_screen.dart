import 'package:flutter/material.dart';
import '../models/budget.dart';
import '../models/category.dart'; // Import the Category model
import '../services/database_service.dart';

class BudgetSettingScreen extends StatefulWidget {
  const BudgetSettingScreen({super.key});

  @override
  _BudgetSettingScreenState createState() => _BudgetSettingScreenState();
}

class _BudgetSettingScreenState extends State<BudgetSettingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _categoryController = TextEditingController();
  final _budgetLimitController = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(Duration(days: 30));
  String? _selectedCategory; // Track the selected category
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

  Future<void> _saveBudget() async {
    if (_formKey.currentState!.validate()) {
      final newBudget = Budget(
        id: DateTime.now().toString(),
        category: _selectedCategory ?? _categoryController.text,
        budgetLimit: double.parse(_budgetLimitController.text),
        startDate: _startDate,
        endDate: _endDate,
      );

      await DatabaseService().insertBudget(newBudget);
      if (!mounted) return; // Check if the widget is still mounted
      Navigator.of(context).pop(); // Go back to the home screen
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

  Future<void> _selectEndDate(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
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
        title: Text('Set Budget'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
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
              TextFormField(
                controller: _budgetLimitController,
                decoration: InputDecoration(labelText: 'Budget Limit'),
                keyboardType: TextInputType.number,
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
              ListTile(
                title: Text(
                    'Start Date: ${_startDate.toLocal().toString().split(' ')[0]}'),
                trailing: Icon(Icons.calendar_today),
                onTap: () => _selectStartDate(context),
              ),
              ListTile(
                title: Text(
                    'End Date: ${_endDate.toLocal().toString().split(' ')[0]}'),
                trailing: Icon(Icons.calendar_today),
                onTap: () => _selectEndDate(context),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveBudget,
                child: Text('Save Budget'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
