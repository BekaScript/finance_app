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
        language TEXT DEFAULT 'en'
      )
    ''');

    // Insert default settings
    await db.insert('settings', {
      'currency': 'USD',
      'language': 'en'
    });
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
}
