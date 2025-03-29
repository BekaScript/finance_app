import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'finance.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL,
        type TEXT,
        category TEXT,
        date TEXT,
        description TEXT,
        isRecurring INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        type TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE budgets(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT,
        budget_limit REAL, -- Renamed from "limit" to "budget_limit"
        month TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE user(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        email TEXT UNIQUE,
        password TEXT,
        is_logged_in INTEGER DEFAULT 0
      )
      ''');

    await db.execute('''
      CREATE TABLE settings(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        currency TEXT DEFAULT 'USD',
        language TEXT DEFAULT 'en',
        isDarkMode INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE exchange_rates(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        currency TEXT UNIQUE,
        rate REAL
      )
    ''');

    // Insert default settings
    await db.insert('settings', {
      'currency': 'USD',
      'language': 'en',
      'isDarkMode': 0
    });

    // Insert default user
    try {
      await db.insert('user', {
        'name': 'Default User',
        'email': 'user@example.com',
        'password': 'password123',
        'is_logged_in': 0
      });
    } catch (e) {
      print('Error creating default user: $e');
    }

    // Insert default exchange rates
    await db.insert('exchange_rates', {'currency': 'KGS', 'rate': 1.0});
    await db.insert('exchange_rates', {'currency': 'USD', 'rate': 89.5});
    await db.insert('exchange_rates', {'currency': 'EUR', 'rate': 95.6});
    await db.insert('exchange_rates', {'currency': 'INR', 'rate': 1.1});
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE user ADD COLUMN is_logged_in INTEGER DEFAULT 0');
      } catch (e) {
        print('Column might already exist: $e');
      }
    }
  }

  Future<int> insertTransaction(Map<String, dynamic> transaction) async {
    final db = await database;
    return await db.insert('transactions', transaction);
  }

  Future<int> updateTransaction(
      Map<String, dynamic> transaction, int id) async {
    final db = await database;
    return await db
        .update('transactions', transaction, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setCurrency(String currency) async {
    final db = await database;
    final List<Map<String, dynamic>> settings = await db.query('settings');
    
    if (settings.isEmpty) {
      await db.insert('settings', {'currency': currency});
    } else {
      await db.update(
        'settings',
        {'currency': currency},
        where: 'id = ?',
        whereArgs: [settings.first['id']],
      );
    }
  }

  Future<String> getCurrency() async {
    final db = await database;
    final List<Map<String, dynamic>> settings = await db.query('settings');
    
    if (settings.isEmpty) {
      await db.insert('settings', {'currency': 'USD'});
      return 'USD';
    }
    
    return settings.first['currency'] as String;
  }

  Future<void> setLanguage(String language) async {
    final db = await database;
    final List<Map<String, dynamic>> settings = await db.query('settings');
    
    if (settings.isEmpty) {
      await db.insert('settings', {'language': language});
    } else {
      await db.update(
        'settings',
        {'language': language},
        where: 'id = ?',
        whereArgs: [settings.first['id']],
      );
    }
  }

  Future<String> getLanguage() async {
    final db = await database;
    final List<Map<String, dynamic>> settings = await db.query('settings');
    
    if (settings.isEmpty) {
      await db.insert('settings', {'language': 'en'});
      return 'en';
    }
    
    return settings.first['language'] as String? ?? 'en';
  }

  Future<void> setDarkMode(bool isDarkMode) async {
    print('DatabaseHelper: Setting dark mode to: $isDarkMode');
    final db = await database;
    final List<Map<String, dynamic>> settings = await db.query('settings');
    
    if (settings.isEmpty) {
      print('DatabaseHelper: No settings found, creating new settings');
      await db.insert('settings', {'isDarkMode': isDarkMode ? 1 : 0});
    } else {
      print('DatabaseHelper: Updating existing settings');
      await db.update(
        'settings',
        {'isDarkMode': isDarkMode ? 1 : 0},
        where: 'id = ?',
        whereArgs: [settings.first['id']],
      );
    }
    print('DatabaseHelper: Dark mode setting saved successfully');
  }

  Future<bool> getDarkMode() async {
    print('DatabaseHelper: Getting dark mode setting');
    final db = await database;
    final List<Map<String, dynamic>> settings = await db.query('settings');
    
    if (settings.isEmpty) {
      print('DatabaseHelper: No settings found, creating default settings');
      await db.insert('settings', {'isDarkMode': 0});
      return false;
    }
    
    final isDarkMode = settings.first['isDarkMode'] == 1;
    print('DatabaseHelper: Retrieved dark mode setting: $isDarkMode');
    return isDarkMode;
  }

  Future<double> getExchangeRate(String currency) async {
    final db = await database;
    final results = await db.query(
      'exchange_rates',
      columns: ['rate'],
      where: 'currency = ?',
      whereArgs: [currency],
    );
    if (results.isEmpty) {
      // Default rates if not set (approximately correct as of 2023)
      final defaultRates = {
        'USD': 89.5,   // 1 USD = 89.5 KGS
        'EUR': 95.6,   // 1 EUR = 95.6 KGS
        'INR': 1.1,    // 1 INR = 1.1 KGS
        'KGS': 1.0,    // 1 KGS = 1 KGS (base currency)
      };
      
      // Store the default rate
      await db.insert('exchange_rates', {
        'currency': currency,
        'rate': defaultRates[currency] ?? 1.0,
      });
      
      return defaultRates[currency] ?? 1.0;
    }
    return results.first['rate'] as double;
  }

  Future<void> setExchangeRate(String currency, double rate) async {
    final db = await database;
    // Check if entry exists
    final results = await db.query(
      'exchange_rates',
      columns: ['id'],
      where: 'currency = ?',
      whereArgs: [currency],
    );
    
    if (results.isEmpty) {
      // Insert new entry
      await db.insert('exchange_rates', {
        'currency': currency,
        'rate': rate,
      });
    } else {
      // Update existing entry
      await db.update(
        'exchange_rates',
        {'rate': rate},
        where: 'currency = ?',
        whereArgs: [currency],
      );
    }
  }
}
