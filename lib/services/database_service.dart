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
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';
import '../models/expense.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/recurring_expense.dart';
import '../models/recurring_budget.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  static Database? _database;
  final Logger _logger = Logger();

  // Increment the database version when schema changes
  static const int _databaseVersion =
      6; // Increased for adding currency columns

  DatabaseService._internal() {
    // Initialize SQLite factory only once
    _initSqfliteFactory();
  }

  void _initSqfliteFactory() {
    if (kIsWeb) {
      // For web
      databaseFactory = databaseFactoryFfiWeb;
    } else if (Platform.isWindows || Platform.isLinux) {
      // For desktop platforms
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    // For mobile platforms, use default SQLite factory
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
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

  Future<Database> _initDatabase() async {
    try {
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

  Future<void> _createDb(Database db, int version) async {
    try {
      // Create expenses table with currency fields
      await db.execute('''
        CREATE TABLE expenses(
          id TEXT PRIMARY KEY,
          title TEXT,
          amount REAL,
          date TEXT,
          category TEXT,
          currency TEXT DEFAULT "USD",
          originalAmount REAL
        )
      ''');

      // Create budgets table with currency field
      await db.execute('''
        CREATE TABLE budgets(
          id TEXT PRIMARY KEY,
          category TEXT,
          budgetLimit REAL,
          startDate TEXT,
          endDate TEXT,
          currency TEXT DEFAULT "USD"
        )
      ''');

      // Create categories table
      await db.execute('''
        CREATE TABLE categories(
          id TEXT PRIMARY KEY,
          name TEXT
        )
      ''');

      // Create recurring_expenses table with currency field
      await db.execute('''
        CREATE TABLE recurring_expenses(
          id TEXT PRIMARY KEY,
          title TEXT,
          amount REAL,
          category TEXT,
          startDate TEXT,
          nextDate TEXT,
          frequency TEXT,
          isActive INTEGER DEFAULT 1,
          currency TEXT DEFAULT "USD"
        )
      ''');

      // Create recurring_budgets table with currency field
      await db.execute('''
        CREATE TABLE recurring_budgets(
          id TEXT PRIMARY KEY,
          category TEXT,
          budgetLimit REAL,
          startDate TEXT,
          nextDate TEXT,
          frequency TEXT,
          currency TEXT DEFAULT "USD"
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

      if (oldVersion < 4) {
        _logger.i('Creating recurring_budgets table');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS recurring_budgets(
            id TEXT PRIMARY KEY,
            category TEXT,
            budgetLimit REAL,
            startDate TEXT,
            nextDate TEXT,
            frequency TEXT
          )
        ''');
      }

      if (oldVersion < 5) {
        // Check if the recurring_expenses table exists
        final tables = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='recurring_expenses'");

        if (tables.isNotEmpty) {
          // Table exists, check if the column exists
          final columns =
              await db.rawQuery("PRAGMA table_info(recurring_expenses)");
          final hasIsActive = columns.any((col) => col['name'] == 'isActive');

          if (!hasIsActive) {
            // Add isActive column to existing table
            _logger.i('Adding isActive column to recurring_expenses table');
            await db.execute('''
              ALTER TABLE recurring_expenses 
              ADD COLUMN isActive INTEGER DEFAULT 1
            ''');
          }
        } else {
          // Table doesn't exist, create it
          _logger.i('Creating recurring_expenses table with isActive column');
          await db.execute('''
            CREATE TABLE recurring_expenses(
              id TEXT PRIMARY KEY,
              title TEXT,
              amount REAL,
              category TEXT,
              startDate TEXT,
              nextDate TEXT,
              frequency TEXT,
              isActive INTEGER DEFAULT 1
            )
          ''');
        }
      }

      if (oldVersion < 6) {
        _logger.i('Adding currency support to database tables');

        // Check and add currency column to expenses table
        final expenseColumns = await db.rawQuery("PRAGMA table_info(expenses)");
        final hasExpensesCurrencyColumn =
            expenseColumns.any((col) => col['name'] == 'currency');

        if (!hasExpensesCurrencyColumn) {
          await db.execute(
              'ALTER TABLE expenses ADD COLUMN currency TEXT DEFAULT "USD"');
          await db
              .execute('ALTER TABLE expenses ADD COLUMN originalAmount REAL');
          _logger.i('Added currency columns to expenses table');
        }

        // Check and add currency column to budgets table
        final budgetColumns = await db.rawQuery("PRAGMA table_info(budgets)");
        final hasBudgetsCurrencyColumn =
            budgetColumns.any((col) => col['name'] == 'currency');

        if (!hasBudgetsCurrencyColumn) {
          await db.execute(
              'ALTER TABLE budgets ADD COLUMN currency TEXT DEFAULT "USD"');
          _logger.i('Added currency column to budgets table');
        }

        // Check and add currency column to recurring_expenses table
        final tables = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='recurring_expenses'");

        if (tables.isNotEmpty) {
          final recExpColumns =
              await db.rawQuery("PRAGMA table_info(recurring_expenses)");
          final hasRecExpCurrencyColumn =
              recExpColumns.any((col) => col['name'] == 'currency');

          if (!hasRecExpCurrencyColumn) {
            await db.execute(
                'ALTER TABLE recurring_expenses ADD COLUMN currency TEXT DEFAULT "USD"');
            _logger.i('Added currency column to recurring_expenses table');
          }
        }

        // Check and add currency column to recurring_budgets table
        final recBudgetTables = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='recurring_budgets'");

        if (recBudgetTables.isNotEmpty) {
          final recBudgetColumns =
              await db.rawQuery("PRAGMA table_info(recurring_budgets)");
          final hasRecBudgetCurrencyColumn =
              recBudgetColumns.any((col) => col['name'] == 'currency');

          if (!hasRecBudgetCurrencyColumn) {
            await db.execute(
                'ALTER TABLE recurring_budgets ADD COLUMN currency TEXT DEFAULT "USD"');
            _logger.i('Added currency column to recurring_budgets table');
          }
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

  // Update an existing expense in the database
  Future<void> updateExpense(Expense expense) async {
    final db = await database;
    await db.update(
      'expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
    _logger.i('Expense updated: ${expense.id}');
  }

  // Delete an expense from the database
  Future<void> deleteExpense(String id) async {
    final db = await database;
    await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
    _logger.i('Expense deleted: $id');
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

  // Update an existing budget in the database
  Future<void> updateBudget(Budget budget) async {
    final db = await database;
    await db.update(
      'budgets',
      budget.toMap(),
      where: 'id = ?',
      whereArgs: [budget.id],
    );
    _logger.i('Budget updated: ${budget.id}');
  }

  // Delete a budget from the database
  Future<void> deleteBudget(String id) async {
    final db = await database;
    await db.delete(
      'budgets',
      where: 'id = ?',
      whereArgs: [id],
    );
    _logger.i('Budget deleted: $id');
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

  // Update an existing recurring expense
  Future<void> updateRecurringExpense(RecurringExpense recurringExpense) async {
    final db = await database;
    await db.update(
      'recurring_expenses',
      recurringExpense.toMap(),
      where: 'id = ?',
      whereArgs: [recurringExpense.id],
    );
    _logger.i('Recurring expense updated: ${recurringExpense.id}');
  }

  // Delete a recurring expense
  Future<void> deleteRecurringExpense(String id) async {
    final db = await database;
    await db.delete(
      'recurring_expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
    _logger.i('Recurring expense deleted: $id');
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

  // Insert a recurring budget into the database
  Future<void> insertRecurringBudget(RecurringBudget recurringBudget) async {
    final db = await database;
    await db.insert('recurring_budgets', recurringBudget.toMap());
    _logger.i('Recurring budget inserted: ${recurringBudget.id}');
  }

  // Update an existing recurring budget
  Future<void> updateRecurringBudget(RecurringBudget recurringBudget) async {
    final db = await database;
    await db.update(
      'recurring_budgets',
      recurringBudget.toMap(),
      where: 'id = ?',
      whereArgs: [recurringBudget.id],
    );
    _logger.i('Recurring budget updated: ${recurringBudget.id}');
  }

  // Delete a recurring budget
  Future<void> deleteRecurringBudget(String id) async {
    final db = await database;
    await db.delete(
      'recurring_budgets',
      where: 'id = ?',
      whereArgs: [id],
    );
    _logger.i('Recurring budget deleted: $id');
  }

  // Retrieve all recurring budgets from the database
  Future<List<RecurringBudget>> getRecurringBudgets() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('recurring_budgets');
    return List.generate(maps.length, (i) {
      return RecurringBudget.fromMap(maps[i]);
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
      _logger.i('No budget set for category: $category');
      return false; // No budget set for this category
    }

    final budget = Budget.fromMap(budgets.first);
    final totalSpent = await getTotalSpendingForCategory(category);

    _logger.i('Budget Limit: ${budget.budgetLimit}, Total Spent: $totalSpent');

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

  // Process recurring expenses that are due
  Future<void> checkAndAddRecurringExpenses() async {
    final db = await database;
    final now = DateTime.now();

    // Get all active recurring expenses
    final recurringExpenses = await db.query(
      'recurring_expenses',
      where: 'isActive = ?',
      whereArgs: [1],
    );

    for (final expenseMap in recurringExpenses) {
      final recurringExpense = RecurringExpense.fromMap(expenseMap);
      if (recurringExpense.nextDate.isBefore(now) ||
          recurringExpense.nextDate.isAtSameMomentAs(now)) {
        // Add the recurring expense to the expenses table
        final newExpense = Expense(
          id: DateTime.now().toString(),
          title: recurringExpense.title,
          amount: recurringExpense.amount,
          date: recurringExpense.nextDate,
          category: recurringExpense.category,
          currency: recurringExpense.currency,
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

  // Process recurring budgets that are due
  Future<void> checkAndAddRecurringBudgets() async {
    try {
      _logger.i('Checking for recurring budgets');
      final db = await database;
      final now = DateTime.now();

      // Get all recurring budgets
      final List<Map<String, dynamic>> recurringBudgets =
          await db.query('recurring_budgets');

      for (final budgetMap in recurringBudgets) {
        final recurringBudget = RecurringBudget.fromMap(budgetMap);
        if (recurringBudget.nextDate.isBefore(now) ||
            recurringBudget.nextDate.isAtSameMomentAs(now)) {
          // Create new budget
          final newBudget = Budget(
            id: DateTime.now().toString(),
            category: recurringBudget.category,
            budgetLimit: recurringBudget.budgetLimit,
            startDate: recurringBudget.nextDate,
            endDate: _calculateNextDate(
                recurringBudget.nextDate, recurringBudget.frequency),
            currency: recurringBudget.currency,
          );

          await insertBudget(newBudget);

          // Update next date
          final newNextDate = _calculateNextDate(
              recurringBudget.nextDate, recurringBudget.frequency);

          await db.update(
            'recurring_budgets',
            {'nextDate': newNextDate.toIso8601String()},
            where: 'id = ?',
            whereArgs: [recurringBudget.id],
          );

          _logger.i(
              'Created new budget from recurring budget: ${recurringBudget.id}');
        }
      }
    } catch (e) {
      _logger.e('Error checking recurring budgets: $e');
    }
  }

  /// Calculate the next date based on frequency
  DateTime _calculateNextDate(DateTime currentDate, String frequency) {
    switch (frequency) {
      case 'Daily':
        return currentDate.add(Duration(days: 1));
      case 'Weekly':
        return currentDate.add(Duration(days: 7));
      case 'Monthly':
        return DateTime(
            currentDate.year, currentDate.month + 1, currentDate.day);
      case 'Quarterly':
        return DateTime(
            currentDate.year, currentDate.month + 3, currentDate.day);
      case 'Yearly':
        return DateTime(
            currentDate.year + 1, currentDate.month, currentDate.day);
      default:
        return currentDate.add(Duration(days: 30)); // Default to monthly
    }
  }
}
