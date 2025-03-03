import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/database_service.dart';
import 'package:logger/logger.dart';

class CategorySettingScreen extends StatefulWidget {
  const CategorySettingScreen({super.key});

  @override
  _CategorySettingScreenState createState() => _CategorySettingScreenState();
}

class _CategorySettingScreenState extends State<CategorySettingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _categoryNameController = TextEditingController();
  List<Category> _categories = [];
  final Logger _logger = Logger();

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await DatabaseService().getCategories();
      setState(() {
        _categories = categories;
      });
      _logger.i('Categories loaded: ${_categories.length}');
    } catch (e) {
      _logger.e(
          'Failed to load categories: $e'); // Fixed: Combined message and exception
    }
  }

  Future<void> _saveCategory() async {
    if (_formKey.currentState!.validate()) {
      final newCategory = Category(
        id: DateTime.now().toString(),
        name: _categoryNameController.text,
      );

      try {
        await DatabaseService().insertCategory(newCategory);
        _categoryNameController.clear();
        _logger.i('Category added: ${newCategory.name}');
        _loadCategories(); // Refresh the list of categories
      } catch (e) {
        _logger.e(
            'Failed to add category: $e'); // Fixed: Combined message and exception
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Categories'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _categoryNameController,
                decoration: const InputDecoration(labelText: 'Category Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a category name';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveCategory,
              child: const Text('Add Category'),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _categories.length,
                itemBuilder: (ctx, index) {
                  final category = _categories[index];
                  return ListTile(
                    title: Text(category.name),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
