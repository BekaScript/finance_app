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
        wallet_id INTEGER,
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
      CREATE TABLE wallets(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        balance REAL DEFAULT 0.0
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
        email TEXT,
        password TEXT,
        is_logged_in INTEGER DEFAULT 0,
        remember_me INTEGER DEFAULT 0
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
    final id = await db.insert('transactions', transaction);
    
    // Update wallet balance
    if (transaction.containsKey('wallet_id') && 
        transaction.containsKey('amount') && 
        transaction.containsKey('type')) {
      await updateWalletBalance(
        transaction['wallet_id'] as int,
        transaction['amount'] as double,
        transaction['type'] as String,
      );
    }
    
    return id;
  }

  Future<int> updateTransaction(Map<String, dynamic> transaction, int id) async {
    final db = await database;
    
    // Get the old transaction to reverse its effect on wallet balance
    final oldTransactions = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1
    );
    
    if (oldTransactions.isNotEmpty) {
      final oldTransaction = oldTransactions.first;
      
      // Reverse the old transaction's effect on wallet balance
      if (oldTransaction.containsKey('wallet_id') && 
          oldTransaction.containsKey('amount') && 
          oldTransaction.containsKey('type')) {
        // Invert the type for reversal
        final reversalType = oldTransaction['type'] == 'income' ? 'expense' : 'income';
        
        await updateWalletBalance(
          oldTransaction['wallet_id'] as int,
          oldTransaction['amount'] as double,
          reversalType,
        );
      }
      
      // Apply the new transaction's effect
      if (transaction.containsKey('wallet_id') && 
          transaction.containsKey('amount') && 
          transaction.containsKey('type')) {
        await updateWalletBalance(
          transaction['wallet_id'] as int,
          transaction['amount'] as double,
          transaction['type'] as String,
        );
      }
    }
    
    // Update the transaction in the database
    return await db.update(
      'transactions', 
      transaction, 
      where: 'id = ?', 
      whereArgs: [id]
    );
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;
    
    // Get the transaction to reverse its effect on wallet balance
    final transactions = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1
    );
    
    if (transactions.isNotEmpty) {
      final transaction = transactions.first;
      
      // Reverse the transaction's effect on wallet balance
      if (transaction.containsKey('wallet_id') && 
          transaction.containsKey('amount') && 
          transaction.containsKey('type')) {
        // Invert the type for reversal
        final reversalType = transaction['type'] == 'income' ? 'expense' : 'income';
        
        await updateWalletBalance(
          transaction['wallet_id'] as int,
          transaction['amount'] as double,
          reversalType,
        );
      }
    }
    
    // Delete the transaction from the database
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
    final db = await database;
    final List<Map<String, dynamic>> settings = await db.query('settings');
    
    if (settings.isEmpty) {
      await db.insert('settings', {'isDarkMode': isDarkMode ? 1 : 0});
    } else {
      await db.update(
        'settings',
        {'isDarkMode': isDarkMode ? 1 : 0},
        where: 'id = ?',
        whereArgs: [settings.first['id']],
      );
    }
  }

  Future<bool> getDarkMode() async {
    final db = await database;
    final List<Map<String, dynamic>> settings = await db.query('settings');
    
    if (settings.isEmpty) {
      await db.insert('settings', {'isDarkMode': 0});
      return false;
    }
    
    return settings.first['isDarkMode'] == 1;
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
  
  // Category management methods
  Future<List<Map<String, dynamic>>> getCategories(String type) async {
    final db = await database;
    return await db.query(
      'categories',
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'name ASC',
    );
  }
  
  Future<List<Map<String, dynamic>>> getAllCategories() async {
    final db = await database;
    return await db.query('categories', orderBy: 'type ASC, name ASC');
  }

  Future<int> insertCategory(Map<String, dynamic> category) async {
    final db = await database;
    return await db.insert('categories', category);
  }

  Future<int> updateCategory(Map<String, dynamic> category, int id) async {
    final db = await database;
    return await db.update(
      'categories',
      category,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    return await db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  // Insert default categories if none exist
  Future<void> insertDefaultCategories() async {
    final db = await database;
    final categories = await db.query('categories');
    
    if (categories.isEmpty) {
      // Default income categories
      await db.insert('categories', {'name': 'Salary', 'type': 'income'});
      await db.insert('categories', {'name': 'Freelance', 'type': 'income'});
      await db.insert('categories', {'name': 'Gifts', 'type': 'income'});
      await db.insert('categories', {'name': 'Investments', 'type': 'income'});
      await db.insert('categories', {'name': 'Other Income', 'type': 'income'});
      
      // Default expense categories
      await db.insert('categories', {'name': 'Food', 'type': 'expense'});
      await db.insert('categories', {'name': 'Transportation', 'type': 'expense'});
      await db.insert('categories', {'name': 'Housing', 'type': 'expense'});
      await db.insert('categories', {'name': 'Utilities', 'type': 'expense'});
      await db.insert('categories', {'name': 'Entertainment', 'type': 'expense'});
      await db.insert('categories', {'name': 'Shopping', 'type': 'expense'});
      await db.insert('categories', {'name': 'Healthcare', 'type': 'expense'});
      await db.insert('categories', {'name': 'Education', 'type': 'expense'});
      await db.insert('categories', {'name': 'Other Expense', 'type': 'expense'});
    }
  }
  
  // Wallet management methods
  
  Future<void> insertDefaultWallets() async {
    final db = await database;
    final wallets = await db.query('wallets');
    
    if (wallets.isEmpty) {
      // Insert default wallets
      await db.insert('wallets', {'name': 'Cash', 'balance': 0.0});
      await db.insert('wallets', {'name': 'Bank Account', 'balance': 0.0});
    } else {
      // Ensure a Cash wallet always exists
      final cashWallet = await db.query(
        'wallets',
        where: 'name = ?',
        whereArgs: ['Cash'],
      );
      
      if (cashWallet.isEmpty) {
        await db.insert('wallets', {'name': 'Cash', 'balance': 0.0});
      }
    }
  }
  
  Future<List<Map<String, dynamic>>> getAllWallets() async {
    final db = await database;
    return await db.query('wallets');
  }
  
  Future<int> insertWallet(Map<String, dynamic> wallet) async {
    try {
      print("Inserting wallet: $wallet");
      final db = await database;
      return await db.insert('wallets', wallet);
    } catch (e) {
      print("Error inserting wallet: $e");
      throw e;
    }
  }
  
  Future<int> updateWallet(Map<String, dynamic> wallet, int id) async {
    final db = await database;
    return await db.update(
      'wallets',
      wallet,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  Future<int> deleteWallet(int id) async {
    final db = await database;
    return await db.delete(
      'wallets',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  Future<void> updateWalletBalance(int walletId, double amount, String type) async {
    final db = await database;
    final wallet = await db.query(
      'wallets',
      where: 'id = ?',
      whereArgs: [walletId],
      limit: 1
    );
    
    if (wallet.isNotEmpty) {
      double currentBalance = wallet.first['balance'] as double;
      double newBalance = currentBalance;
      
      if (type == 'income') {
        newBalance += amount;
      } else if (type == 'expense') {
        newBalance -= amount;
      }
      
      await db.update(
        'wallets',
        {'balance': newBalance},
        where: 'id = ?',
        whereArgs: [walletId],
      );
    }
  }

  // Transfer money between wallets (for drag and drop feature)
  Future<bool> transferBetweenWallets(int sourceWalletId, int destinationWalletId, double amount) async {
    if (sourceWalletId == destinationWalletId) {
      print('Cannot transfer to the same wallet');
      return false;
    }

    if (amount <= 0) {
      print('Transfer amount must be positive');
      return false;
    }

    final db = await database;
    try {
      // Use a transaction to ensure both operations complete or both fail
      return await db.transaction((txn) async {
        // Get source wallet and check balance
        final sourceWalletResult = await txn.query(
          'wallets',
          where: 'id = ?',
          whereArgs: [sourceWalletId],
        );
        
        if (sourceWalletResult.isEmpty) {
          print('Source wallet not found');
          return false;
        }
        
        final sourceWallet = sourceWalletResult.first;
        final sourceBalance = sourceWallet['balance'] as double;
        
        if (sourceBalance < amount) {
          print('Insufficient funds in source wallet');
          return false;
        }
        
        // Get destination wallet
        final destWalletResult = await txn.query(
          'wallets',
          where: 'id = ?',
          whereArgs: [destinationWalletId],
        );
        
        if (destWalletResult.isEmpty) {
          print('Destination wallet not found');
          return false;
        }
        
        final destWallet = destWalletResult.first;
        final destBalance = destWallet['balance'] as double;
        
        // Update source wallet (subtract amount)
        await txn.update(
          'wallets',
          {'balance': sourceBalance - amount},
          where: 'id = ?',
          whereArgs: [sourceWalletId],
        );
        
        // Update destination wallet (add amount)
        await txn.update(
          'wallets',
          {'balance': destBalance + amount},
          where: 'id = ?',
          whereArgs: [destinationWalletId],
        );
        
        // Add a transaction record of type 'transfer'
        final now = DateTime.now();
        final formattedDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
        
        await txn.insert('transactions', {
          'amount': amount,
          'type': 'transfer',
          'category': 'Transfer',
          'date': formattedDate,
          'description': 'Transfer from ${sourceWallet['name']} to ${destWallet['name']}',
          'wallet_id': sourceWalletId,
        });
        
        print('Transfer completed successfully');
        return true;
      });
    } catch (e) {
      print('Error during transfer: $e');
      return false;
    }
  }
}
