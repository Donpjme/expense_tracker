import 'dart:io' show Platform, Directory;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show
        Database,
        databaseFactory,
        databaseFactoryFfi,
        getDatabasesPath,
        openDatabase,
        sqfliteFfiInit;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart'; // Add this import
import 'package:logger/logger.dart';
import '../models/expense.dart';
import '../models/budget.dart'; // Import the Budget model
import '../models/category.dart'; // Import the Category model
import '../models/recurring_expense.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  static Database? _database;
  final Logger _logger = Logger();

  // Increment the database version
  static const int _databaseVersion = 3; // Changed from 2 to 3

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      // Initialize sqflite_ffi for non-web platforms
      if (!kIsWeb) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      } else {
        // Initialize sqflite_ffi_web for web platforms
        databaseFactory = databaseFactoryFfiWeb;
      }

      // Get the database path
      final dbPath = await _getDatabasePath();
      final path = join(dbPath, 'expenses.db');

      _logger.i('Database path: $path');

      // Ensure the directory exists
      final dir = Directory(dbPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // Open or create the database
      final db = await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _createDb,
        onUpgrade: _upgradeDb,
      );

      _logger.i('Database initialized successfully');
      return db;
    } catch (e) {
      _logger.e('Failed to initialize database: $e');
      rethrow; // Rethrow the exception to handle it in the calling code
    }
  }

  Future<String> _getDatabasePath() async {
    if (Platform.isIOS || Platform.isAndroid) {
      // Use the app's documents directory for mobile platforms
      final appDocumentsDir = await getApplicationDocumentsDirectory();
      return appDocumentsDir.path;
    } else {
      // Use the default database path for other platforms
      return await getDatabasesPath();
    }
  }

  Future<void> _createDb(Database db, int version) async {
    try {
      // Create expenses table
      await db.execute('''
        CREATE TABLE expenses(
          id TEXT PRIMARY KEY,
          title TEXT,
          amount REAL,
          date TEXT,
          category TEXT
        )
      ''');

      // Create budgets table
      await db.execute('''
        CREATE TABLE budgets(
          id TEXT PRIMARY KEY,
          category TEXT,
          budgetLimit REAL,
          startDate TEXT,
          endDate TEXT
        )
      ''');

      // Create categories table
      await db.execute('''
        CREATE TABLE categories(
          id TEXT PRIMARY KEY,
          name TEXT
        )
      ''');

      // Create recurring_expenses table
      await db.execute('''
        CREATE TABLE recurring_expenses(
          id TEXT PRIMARY KEY,
          title TEXT,
          amount REAL,
          category TEXT,
          startDate TEXT,
          nextDate TEXT,
          frequency TEXT
        )
      ''');

      // Insert preloaded categories
      await db.insert('categories', {'id': '1', 'name': 'Food'});
      await db.insert('categories', {'id': '2', 'name': 'Transport'});
      await db.insert('categories', {'id': '3', 'name': 'Entertainment'});
      await db.insert('categories', {'id': '4', 'name': 'Utilities'});
      await db.insert('categories', {'id': '5', 'name': 'Health'});
      await db.insert('categories', {'id': '6', 'name': 'Education'});
      await db.insert('categories', {'id': '7', 'name': 'Shopping'});
      await db.insert('categories', {'id': '8', 'name': 'Miscellaneous'});

      _logger
          .i('Database tables created successfully with preloaded categories');
    } catch (e) {
      _logger.e('Failed to create database tables: $e');
      rethrow;
    }
  }

  // Handle database upgrades
  Future<void> _upgradeDb(Database db, int oldVersion, int newVersion) async {
    try {
      _logger.i('Upgrading database from version $oldVersion to $newVersion');

      if (oldVersion < 3) {
        _logger.i('Creating budgets and categories tables');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS budgets(
            id TEXT PRIMARY KEY,
            category TEXT,
            budgetLimit REAL,
            startDate TEXT,
            endDate TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS categories(
            id TEXT PRIMARY KEY,
            name TEXT
          )
        ''');

        // Insert preloaded categories if they do not exist
        final existingCategories = await db.query('categories');
        if (existingCategories.isEmpty) {
          await db.insert('categories', {'id': '1', 'name': 'Food'});
          await db.insert('categories', {'id': '2', 'name': 'Transport'});
          await db.insert('categories', {'id': '3', 'name': 'Entertainment'});
          await db.insert('categories', {'id': '4', 'name': 'Utilities'});
          await db.insert('categories', {'id': '5', 'name': 'Health'});
          await db.insert('categories', {'id': '6', 'name': 'Education'});
          await db.insert('categories', {'id': '7', 'name': 'Shopping'});
          await db.insert('categories', {'id': '8', 'name': 'Miscellaneous'});
        }
      }

      _logger.i('Database upgrade completed successfully');
    } catch (e) {
      _logger.e('Failed to upgrade database: $e');
      rethrow;
    }
  }

  // Insert an expense into the database
  Future<void> insertExpense(Expense expense) async {
    final db = await database;
    await db.insert('expenses', expense.toMap());
  }

  // Retrieve all expenses from the database
  Future<List<Expense>> getExpenses() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('expenses');
    return List.generate(maps.length, (i) {
      return Expense.fromMap(maps[i]);
    });
  }

  // Insert a budget into the database
  Future<void> insertBudget(Budget budget) async {
    final db = await database;
    await db.insert('budgets', budget.toMap());
  }

  // Retrieve all budgets from the database
  Future<List<Budget>> getBudgets() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('budgets');
    return List.generate(maps.length, (i) {
      return Budget.fromMap(maps[i]);
    });
  }

  // Insert a category into the database
  Future<void> insertCategory(Category category) async {
    final db = await database;
    await db.insert('categories', category.toMap());
  }

  // Retrieve all categories from the database
  Future<List<Category>> getCategories() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('categories');
    return List.generate(maps.length, (i) {
      return Category.fromMap(maps[i]);
    });
  }

  // Insert a recurring expense into the database
  Future<void> insertRecurringExpense(RecurringExpense recurringExpense) async {
    final db = await database;
    await db.insert('recurring_expenses', recurringExpense.toMap());
  }

  // Retrieve all recurring expenses from the database
  Future<List<RecurringExpense>> getRecurringExpenses() async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query('recurring_expenses');
    return List.generate(maps.length, (i) {
      return RecurringExpense.fromMap(maps[i]);
    });
  }

  // Calculate total spending for a specific category
  Future<double> getTotalSpendingForCategory(String category) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'expenses',
      where: 'category = ?',
      whereArgs: [category],
    );

    double totalSpent = 0.0;
    for (final map in maps) {
      totalSpent += map['amount'] as double;
    }
    return totalSpent;
  }

  // Check if the budget is exceeded for a specific category
  Future<bool> isBudgetExceeded(String category) async {
    final db = await database;
    final budgets = await db.query(
      'budgets',
      where: 'category = ?',
      whereArgs: [category],
    );

    if (budgets.isEmpty) {
      _logger.i(
          'No budget set for category: $category'); // Use logger instead of print
      return false; // No budget set for this category
    }

    final budget = Budget.fromMap(budgets.first);
    final totalSpent = await getTotalSpendingForCategory(category);

    _logger.i(
        'Budget Limit: ${budget.budgetLimit}, Total Spent: $totalSpent'); // Use logger instead of print

    return totalSpent > budget.budgetLimit;
  }

  // Get the budget for a specific category
  Future<Budget> getBudgetForCategory(String category) async {
    final db = await database;
    final budgets = await db.query(
      'budgets',
      where: 'category = ?',
      whereArgs: [category],
    );

    if (budgets.isEmpty) {
      throw Exception('No budget set for this category');
    }

    return Budget.fromMap(budgets.first);
  }

  Future<void> checkAndAddRecurringExpenses() async {
    final db = await database;
    final now = DateTime.now();

    // Get all recurring expenses
    final recurringExpenses = await getRecurringExpenses();

    for (final recurringExpense in recurringExpenses) {
      if (recurringExpense.nextDate.isBefore(now) ||
          recurringExpense.nextDate.isAtSameMomentAs(now)) {
        // Add the recurring expense to the expenses table
        final newExpense = Expense(
          id: DateTime.now().toString(),
          title: recurringExpense.title,
          amount: recurringExpense.amount,
          date: recurringExpense.nextDate,
          category: recurringExpense.category,
        );
        await insertExpense(newExpense);

        // Update the nextDate for the recurring expense
        final nextDate = _calculateNextDate(
            recurringExpense.nextDate, recurringExpense.frequency);
        await db.update(
          'recurring_expenses',
          {'nextDate': nextDate.toIso8601String()},
          where: 'id = ?',
          whereArgs: [recurringExpense.id],
        );
      }
    }
  }

  DateTime _calculateNextDate(DateTime currentDate, String frequency) {
    switch (frequency) {
      case 'Daily':
        return currentDate.add(Duration(days: 1));
      case 'Weekly':
        return currentDate.add(Duration(days: 7));
      case 'Monthly':
        return DateTime(
            currentDate.year, currentDate.month + 1, currentDate.day);
      default:
        return currentDate;
    }
  }
}
