import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show Database, databaseFactory, databaseFactoryFfi, getDatabasesPath, openDatabase, sqfliteFfiInit;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart';
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
    if (kIsWeb) {
      // Initialize the database factory for web
      databaseFactory = databaseFactoryFfiWeb;
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Initialize the database factory for desktop
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    } else {
      // Initialize the database factory for mobile
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'expenses.db');

    final db = await openDatabase(
      path,
      version: _databaseVersion, // Use the updated version
      onCreate: _createDb,
      onUpgrade: _upgradeDb, // Add the onUpgrade method
    );

    // Verify if the budgets table exists
    final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='budgets'");
    if (tables.isEmpty) {
      _logger.i('Budgets table does not exist. Creating it now.');
      await db.execute('''
        CREATE TABLE budgets(
          id TEXT PRIMARY KEY,
          category TEXT,
          budgetLimit REAL,
          startDate TEXT,
          endDate TEXT
        )
      ''');
    } else {
      _logger.i('Budgets table already exists.');
    }

    return db;
  }

  Future<void> _createDb(Database db, int version) async {
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
  }

  // Handle database upgrades
  Future<void> _upgradeDb(Database db, int oldVersion, int newVersion) async {
    _logger.i('Upgrading database from version $oldVersion to $newVersion');
    if (oldVersion < 3) {
      _logger.i('Creating budgets table');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS budgets(
          id TEXT PRIMARY KEY,
          category TEXT,
          budgetLimit REAL,
          startDate TEXT,
          endDate TEXT
        )
      ''');
    }
    if (oldVersion < 3) {
      _logger.i('Creating categories table');
      await db.execute('''
      CREATE TABLE IF NOT EXISTS categories(
        id TEXT PRIMARY KEY,
        name TEXT
      )
    ''');
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
