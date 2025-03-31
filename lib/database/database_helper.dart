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

    // Не удаляем базу данных, а просто открываем или создаем её
    print("Открываем или создаем базу данных: $path");
    return await openDatabase(
      path,
      version: 3,
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
        user_id INTEGER,
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
        balance REAL DEFAULT 0.0,
        type TEXT,
        user_id INTEGER
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
    await db.insert(
        'settings', {'currency': 'USD', 'language': 'en', 'isDarkMode': 0});

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
        await db.execute(
            'ALTER TABLE user ADD COLUMN is_logged_in INTEGER DEFAULT 0');
      } catch (e) {
        print('Column might already exist: $e');
      }
    }

    if (oldVersion < 3) {
      try {
        // Проверяем существование таблицы user
        final tables = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='user'");

        if (tables.isNotEmpty) {
          // Создаем временную таблицу
          await db.execute('''
            CREATE TABLE user_temp(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT,
              email TEXT UNIQUE,
              password TEXT,
              is_logged_in INTEGER DEFAULT 0,
              remember_me INTEGER DEFAULT 0
            )
          ''');

          // Копируем данные из старой таблицы, игнорируя дубликаты
          await db.execute('''
            INSERT OR IGNORE INTO user_temp(id, name, email, password, is_logged_in, remember_me)
            SELECT id, name, email, password, is_logged_in, remember_me FROM user
          ''');

          // Удаляем старую таблицу
          await db.execute('DROP TABLE user');

          // Переименовываем временную таблицу
          await db.execute('ALTER TABLE user_temp RENAME TO user');

          print(
              'Успешно обновлена таблица user с уникальным ограничением на email');
        }
      } catch (e) {
        print('Ошибка при обновлении таблицы user: $e');
      }
    }
  }

  Future<int> insertTransaction(Map<String, dynamic> transaction) async {
    final db = await database;
    final int? userId = await getCurrentUserId();

    // Add userId to transaction if user is logged in
    if (userId != null) {
      transaction['user_id'] = userId;
    }

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

  Future<int> updateTransaction(
      Map<String, dynamic> transaction, int id) async {
    final db = await database;

    // Get the old transaction to reverse its effect on wallet balance
    final oldTransactions = await db.query('transactions',
        where: 'id = ?', whereArgs: [id], limit: 1);

    if (oldTransactions.isNotEmpty) {
      final oldTransaction = oldTransactions.first;

      // Reverse the old transaction's effect on wallet balance
      if (oldTransaction.containsKey('wallet_id') &&
          oldTransaction.containsKey('amount') &&
          oldTransaction.containsKey('type')) {
        // Invert the type for reversal
        final reversalType =
            oldTransaction['type'] == 'income' ? 'expense' : 'income';

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
    return await db
        .update('transactions', transaction, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;

    // Get the transaction to reverse its effect on wallet balance
    final transactions = await db.query('transactions',
        where: 'id = ?', whereArgs: [id], limit: 1);

    if (transactions.isNotEmpty) {
      final transaction = transactions.first;

      // Reverse the transaction's effect on wallet balance
      if (transaction.containsKey('wallet_id') &&
          transaction.containsKey('amount') &&
          transaction.containsKey('type')) {
        // Invert the type for reversal
        final reversalType =
            transaction['type'] == 'income' ? 'expense' : 'income';

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
        'USD': 89.5, // 1 USD = 89.5 KGS
        'EUR': 95.6, // 1 EUR = 95.6 KGS
        'INR': 1.1, // 1 INR = 1.1 KGS
        'KGS': 1.0, // 1 KGS = 1 KGS (base currency)
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

      // Default expense categories
      await db.insert('categories', {'name': 'Food', 'type': 'expense'});
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
    try {
      await _ensureWalletsTableExists();
      final db = await database;
      final int? userId = await getCurrentUserId();

      if (userId != null) {
        // Получаем кошельки текущего пользователя
        return await db
            .query('wallets', where: 'user_id = ?', whereArgs: [userId]);
      } else {
        // В гостевом режиме получаем кошельки без user_id
        return await db.query('wallets', where: 'user_id IS NULL');
      }
    } catch (e) {
      print("Ошибка при получении кошельков: $e");
      return [];
    }
  }

  Future<int> insertWallet(Map<String, dynamic> wallet) async {
    try {
      print("Inserting wallet: $wallet");
      await _ensureWalletsTableExists();
      final db = await database;

      // Добавляем user_id, если пользователь авторизован
      final int? userId = await getCurrentUserId();
      if (userId != null) {
        wallet['user_id'] = userId;
      }

      return await db.insert('wallets', wallet);
    } catch (e) {
      print("Error inserting wallet: $e");
      rethrow;
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

  Future<void> updateWalletBalance(
      int walletId, double amount, String type) async {
    final db = await database;
    final wallet = await db.query('wallets',
        where: 'id = ?', whereArgs: [walletId], limit: 1);

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
  Future<bool> transferBetweenWallets(
      int sourceWalletId, int destinationWalletId, double amount) async {
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
        final formattedDate =
            "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

        await txn.insert('transactions', {
          'amount': amount,
          'type': 'transfer',
          'category': 'Transfer',
          'date': formattedDate,
          'description':
              'Transfer from ${sourceWallet['name']} to ${destWallet['name']}',
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

  // Сброс данных транзакций только для текущего пользователя
  Future<bool> resetTransactionData() async {
    final db = await database;
    try {
      return await db.transaction((txn) async {
        // Получаем ID текущего пользователя
        final int? userId = await getCurrentUserId();

        if (userId != null) {
          // Удаляем только транзакции текущего пользователя
          await txn.delete('transactions',
              where: 'user_id = ?', whereArgs: [userId]);
        } else {
          // В гостевом режиме удаляем только транзакции без user_id
          await txn.delete('transactions', where: 'user_id IS NULL');
        }

        // Получаем кошельки текущего пользователя
        final List<Map<String, dynamic>> wallets;
        if (userId != null) {
          wallets = await txn
              .query('wallets', where: 'user_id = ?', whereArgs: [userId]);
        } else {
          wallets = await txn.query('wallets', where: 'user_id IS NULL');
        }

        // Сбрасываем баланс кошельков
        for (var wallet in wallets) {
          await txn.update(
            'wallets',
            {'balance': 0.0},
            where: 'id = ?',
            whereArgs: [wallet['id']],
          );
        }

        return true;
      });
    } catch (e) {
      print('Error resetting transaction data: $e');
      return false;
    }
  }

  // Метод для полного разделения данных между пользователями
  Future<void> _ensureUserDataSeparation() async {
    final db = await database;
    try {
      print("Обеспечение разделения данных пользователей...");

      // Проверяем, есть ли колонка user_id в таблицах
      final transactionsColumns =
          await db.rawQuery('PRAGMA table_info(transactions)');
      final walletsColumns = await db.rawQuery('PRAGMA table_info(wallets)');

      bool transactionsHasUserId = false;
      bool walletsHasUserId = false;

      for (var col in transactionsColumns) {
        if (col['name'] == 'user_id') {
          transactionsHasUserId = true;
          break;
        }
      }

      for (var col in walletsColumns) {
        if (col['name'] == 'user_id') {
          walletsHasUserId = true;
          break;
        }
      }

      // Добавляем колонку user_id при необходимости
      if (!transactionsHasUserId) {
        await db.execute('ALTER TABLE transactions ADD COLUMN user_id INTEGER');
        print('Добавлена колонка user_id в таблицу transactions');
      }

      if (!walletsHasUserId) {
        await db.execute('ALTER TABLE wallets ADD COLUMN user_id INTEGER');
        print('Добавлена колонка user_id в таблицу wallets');
      }

      // Определяем текущего пользователя
      final currentUser = await getCurrentUserId();

      // Если есть транзакции или кошельки без user_id и пользователь залогинен,
      // присваиваем их текущему пользователю
      if (currentUser != null) {
        final transactions =
            await db.query('transactions', where: 'user_id IS NULL');

        if (transactions.isNotEmpty) {
          print(
              'Найдено ${transactions.length} транзакций без привязки к пользователю. Привязываем к ID $currentUser');
          await db.execute(
              'UPDATE transactions SET user_id = ? WHERE user_id IS NULL',
              [currentUser]);
        }

        final wallets = await db.query('wallets', where: 'user_id IS NULL');

        if (wallets.isNotEmpty) {
          print(
              'Найдено ${wallets.length} кошельков без привязки к пользователю. Привязываем к ID $currentUser');
          await db.execute(
              'UPDATE wallets SET user_id = ? WHERE user_id IS NULL',
              [currentUser]);
        }
      }

      print("Обеспечение разделения данных пользователей завершено");
    } catch (e) {
      print('Ошибка при обеспечении разделения данных пользователей: $e');
    }
  }

  // Логаут пользователя
  Future<bool> logoutUser() async {
    final db = await database;
    try {
      // Получаем текущий ID пользователя
      final currentUserId = await getCurrentUserId();

      if (currentUserId != null) {
        // Выходим только из текущего аккаунта
        await db.update('user', {'is_logged_in': 0},
            where: 'id = ?', whereArgs: [currentUserId]);

        print('Пользователь с ID $currentUserId вышел из системы');
      } else {
        // Если никто не залогинен, выходим из всех (на всякий случай)
        await db.update('user', {'is_logged_in': 0});
        print('Выход из всех аккаунтов');
      }

      return true;
    } catch (e) {
      print('Ошибка при логауте пользователя: $e');
      return false;
    }
  }

  // Логин пользователя с полным разделением данных
  Future<Map<String, dynamic>?> loginUser(
      String email, String password, bool rememberMe) async {
    await _ensureUserDataSeparation();
    final db = await database;

    try {
      print('Попытка входа пользователя с email: $email');

      // Проверяем учетные данные
      final List<Map<String, dynamic>> users = await db.query(
        'user',
        where: 'email = ? AND password = ?',
        whereArgs: [email, password],
      );

      if (users.isEmpty) {
        print('Пользователь с email $email не найден или неверный пароль');
        return null; // Неверные учетные данные
      }

      // Сначала выходим из всех аккаунтов
      await db.update('user', {'is_logged_in': 0});

      // Обновляем статус входа пользователя
      final user = users.first;
      final userId = user['id'] as int;
      print('Пользователь найден: ID $userId, имя: ${user['name']}');

      await db.update(
        'user',
        {
          'is_logged_in': 1,
          'remember_me': rememberMe ? 1 : 0,
        },
        where: 'id = ?',
        whereArgs: [userId],
      );

      // Проверяем, есть ли у пользователя кошельки
      final wallets = await db.query(
        'wallets',
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      print('Кошельки пользователя: ${wallets.length}');

      // Если у пользователя нет кошельков, создаем стартовый кошелек
      if (wallets.isEmpty) {
        print('Создаем начальный кошелек для пользователя $userId');
        await db.insert('wallets', {
          'name': 'Cash',
          'balance': 0.0,
          'type': 'Cash',
          'user_id': userId
        });
      }

      // После логина еще раз убеждаемся, что все данные корректно разделены
      await _ensureUserDataSeparation();

      return user;
    } catch (e) {
      print('Ошибка при входе пользователя: $e');
      return null;
    }
  }

  // Регистрация пользователя с созданием уникального аккаунта
  Future<int> registerUser(Map<String, dynamic> userData) async {
    await _ensureUserDataSeparation();
    final db = await database;

    try {
      final email = userData['email'] as String;
      print('Регистрация нового пользователя: $email');

      // Проверяем, существует ли пользователь
      final List<Map<String, dynamic>> existingUsers = await db.query(
        'user',
        where: 'email = ?',
        whereArgs: [email],
      );

      if (existingUsers.isNotEmpty) {
        print('Пользователь с email $email уже существует');
        return -1; // Пользователь уже существует
      }

      // Сначала выходим из всех аккаунтов
      await db.update('user', {'is_logged_in': 0});

      // Устанавливаем статус входа для нового пользователя
      userData['is_logged_in'] = 1;

      // Вставляем нового пользователя
      final userId = await db.insert('user', userData);
      print('Создан новый пользователь с ID: $userId');

      if (userId > 0) {
        // Создаем начальный кошелек для нового пользователя
        final wallet = {
          'name': 'Cash',
          'balance': 0.0,
          'type': 'Cash',
          'user_id': userId
        };

        final walletId = await db.insert('wallets', wallet);
        print(
            'Создан начальный кошелек с ID $walletId для пользователя $userId');

        // Подтверждаем, что кошелек создан для правильного пользователя
        final wallets = await db
            .query('wallets', where: 'user_id = ?', whereArgs: [userId]);

        print('Кошельки для пользователя $userId: ${wallets.length}');
      }

      return userId;
    } catch (e) {
      print('Ошибка при регистрации пользователя: $e');
      return -2; // Ошибка регистрации
    }
  }

  // Get current logged-in user's ID
  Future<int?> getCurrentUserId() async {
    final db = await database;

    final List<Map<String, dynamic>> users = await db.query(
      'user',
      columns: ['id', 'name', 'email'],
      where: 'is_logged_in = ?',
      whereArgs: [1],
      limit: 1,
    );

    if (users.isEmpty) {
      print("Текущий пользователь не найден, работаем в гостевом режиме");
      return null;
    }

    final user = users.first;
    final userId = user['id'] as int;
    print(
        "Текущий пользователь: ID: $userId, Имя: ${user['name']}, Email: ${user['email']}");

    return userId;
  }

  // Get transactions for the current user or guest mode
  Future<List<Map<String, dynamic>>> getTransactions() async {
    final db = await database;
    final int? userId = await getCurrentUserId();

    try {
      if (userId != null) {
        // Get transactions for logged-in user
        print("Получаем транзакции для пользователя с ID: $userId");
        final transactions = await db.query('transactions',
            where: 'user_id = ?', whereArgs: [userId], orderBy: 'date DESC');
        print(
            "Найдено ${transactions.length} транзакций для пользователя $userId");
        return transactions;
      } else {
        // Guest mode - get transactions with no user_id
        print("Режим гостя: получаем транзакции без user_id");
        final transactions = await db.query('transactions',
            where: 'user_id IS NULL', orderBy: 'date DESC');
        print("Найдено ${transactions.length} транзакций в гостевом режиме");
        return transactions;
      }
    } catch (e) {
      print("Ошибка при получении транзакций: $e");
      return [];
    }
  }

  // Создаем таблицу wallets, если она не существует
  Future<void> _ensureWalletsTableExists() async {
    try {
      final db = await database;
      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='wallets'");

      if (tables.isEmpty) {
        print("Таблица wallets не существует, создаем ее...");
        await db.execute('''
          CREATE TABLE wallets(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            balance REAL DEFAULT 0.0,
            type TEXT,
            user_id INTEGER
          )
        ''');
        print("Таблица wallets успешно создана");
      } else {
        print("Таблица wallets уже существует");
      }
    } catch (e) {
      print("Ошибка при проверке/создании таблицы wallets: $e");
    }
  }

  // Get the user's display name - simplified to just return empty for non-logged in users
  Future<String> getDisplayName() async {
    final db = await database;

    // First check for logged in user
    final List<Map<String, dynamic>> users = await db.query('user',
        where: 'is_logged_in = ?', whereArgs: [1], limit: 1);

    if (users.isNotEmpty) {
      return users.first['name'] ?? '';
    }

    return ''; // Return empty if no logged in user
  }

  // Get transaction history for specific date range with summary totals
  Future<Map<String, dynamic>> getTransactionHistory(
      DateTime startDate, DateTime endDate) async {
    final db = await database;
    final int? userId = await getCurrentUserId();

    try {
      // Format dates for SQL query
      final String startDateStr = startDate.toIso8601String().substring(0, 10);
      final String endDateStr = endDate.toIso8601String().substring(0, 10);

      // Prepare query conditions
      String userFilter = '';
      List<dynamic> whereArgs = [startDateStr, endDateStr];

      if (userId != null) {
        userFilter = 'AND user_id = ?';
        whereArgs.add(userId);
      } else {
        userFilter = 'AND user_id IS NULL';
      }

      // Get transactions for the date range
      final transactions = await db.query('transactions',
          where: 'date BETWEEN ? AND ? $userFilter',
          whereArgs: whereArgs,
          orderBy: 'date DESC');

      // Calculate totals
      double totalIncome = 0.0;
      double totalExpense = 0.0;

      for (var transaction in transactions) {
        if (transaction['type'] == 'income') {
          totalIncome += transaction['amount'] as double;
        } else if (transaction['type'] == 'expense') {
          totalExpense += transaction['amount'] as double;
        }
      }

      // Group transactions by category for summary
      Map<String, double> incomeByCategory = {};
      Map<String, double> expenseByCategory = {};

      for (var transaction in transactions) {
        final category = transaction['category'] as String;
        final amount = transaction['amount'] as double;

        if (transaction['type'] == 'income') {
          incomeByCategory[category] =
              (incomeByCategory[category] ?? 0) + amount;
        } else if (transaction['type'] == 'expense') {
          expenseByCategory[category] =
              (expenseByCategory[category] ?? 0) + amount;
        }
      }

      return {
        'startDate': startDateStr,
        'endDate': endDateStr,
        'transactions': transactions,
        'totalIncome': totalIncome,
        'totalExpense': totalExpense,
        'balance': totalIncome - totalExpense,
        'incomeByCategory': incomeByCategory,
        'expenseByCategory': expenseByCategory,
      };
    } catch (e) {
      print("Error getting transaction history: $e");
      return {
        'startDate': startDate.toIso8601String().substring(0, 10),
        'endDate': endDate.toIso8601String().substring(0, 10),
        'transactions': [],
        'totalIncome': 0.0,
        'totalExpense': 0.0,
        'balance': 0.0,
        'incomeByCategory': {},
        'expenseByCategory': {},
      };
    }
  }
}
