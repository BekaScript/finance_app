import 'package:flutter/material.dart';
import 'package:nur_budget/pages/AddTransactionScreen.dart';
import 'package:nur_budget/database/database_helper.dart';
import 'package:nur_budget/pages/LogingRegister.dart';
import 'package:nur_budget/widgets/summary_card.dart';
import '../utils/currency_utils.dart';
import '../services/language_service.dart';
import '../pages/CategoryScreen.dart';
import 'package:provider/provider.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late DatabaseHelper dbHelper;
  late Future<List<Map<String, dynamic>>> _transactionsFuture;
  late Future<List<Map<String, dynamic>>> _walletsFuture;

  double _totalIncome = 0.0;
  double _totalExpenses = 0.0;
  double _balance = 0.0;

  // Add user data state variables
  String _userName = '';
  String _userEmail = '';
  String _currencySymbol = '\$';
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late LanguageService _languageService;
  
  // For wallet transfers
  final TextEditingController _transferAmountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    dbHelper = DatabaseHelper();
    _loadInitialData();
  }
  
  @override
  void dispose() {
    _transferAmountController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _languageService = Provider.of<LanguageService>(context, listen: false);
    _loadCurrency();
  }

  // Combine all data loading methods into one
  void _loadInitialData() {
    _loadCurrency();
    _loadData();
    _loadUserData();
    _loadLanguage();
  }

  // Load transactions and summary data
  void _loadData() {
    _transactionsFuture = _fetchTransactions();
    _walletsFuture = _fetchWallets();
    _fetchSummaryData();
  }
  
  // Fetch all wallets
  Future<List<Map<String, dynamic>>> _fetchWallets() async {
    try {
      // Получаем ID текущего пользователя
      final userId = await _dbHelper.getCurrentUserId();
      print("Загрузка кошельков для пользователя с ID: $userId");
      
      final wallets = await _dbHelper.getAllWallets();
      print("Загружено ${wallets.length} кошельков");
      
      // Выводим информацию о каждом кошельке
      for (var wallet in wallets) {
        print("Кошелек ID: ${wallet['id']}, Имя: ${wallet['name']}, Пользователь: ${wallet['user_id']}");
      }
      
      return wallets;
    } catch (e) {
      print("Error fetching wallets: $e");
      return [];
    }
  }

  // Fetch summary data (income, expenses, balance)
  Future<void> _fetchSummaryData() async {
    try {
      final db = await dbHelper.database;
      final int? userId = await _dbHelper.getCurrentUserId();
      
      String userFilter = '';
      List<dynamic> whereArgs = [];
      
      if (userId != null) {
        userFilter = 'AND user_id = ?';
        whereArgs = [userId];
        print("Запрашиваем статистику для пользователя с ID: $userId");
      } else {
        userFilter = 'AND user_id IS NULL';
        print("Запрашиваем статистику в гостевом режиме");
      }

      // Get total income
      final incomeResult = await db.rawQuery(
          "SELECT SUM(amount) as total FROM transactions WHERE type = 'income' $userFilter", 
          whereArgs);
      _totalIncome = incomeResult.first['total'] != null
          ? (incomeResult.first['total'] as num).toDouble()
          : 0.0;

      // Get total expenses
      final expenseResult = await db.rawQuery(
          "SELECT SUM(amount) as total FROM transactions WHERE type = 'expense' $userFilter", 
          whereArgs);
      _totalExpenses = expenseResult.first['total'] != null
          ? (expenseResult.first['total'] as num).toDouble()
          : 0.0;

      // Calculate balance
      _balance = _totalIncome - _totalExpenses;
      
      print("Статистика: доход=$_totalIncome, расходы=$_totalExpenses, баланс=$_balance");

      setState(() {}); // Refresh UI
    } catch (e) {
      print("Error fetching summary data: $e");
    }
  }

  // Fetch all transactions
  Future<List<Map<String, dynamic>>> _fetchTransactions() async {
    try {
      print("Запрашиваем транзакции для текущего пользователя");
      final transactions = await _dbHelper.getTransactions();
      print("Получено ${transactions.length} транзакций");
      
      // Дополнительное логирование для отладки
      if (transactions.isNotEmpty) {
        print("Первая транзакция: ${transactions.first}");
      }
      
      return transactions;
    } catch (e) {
      print("Error fetching transactions: $e");
      return [];
    }
  }

  // Modified to get current user's data
  Future<void> _loadUserData() async {
    final db = await _dbHelper.database;
    // Get the most recently logged in user
    final List<Map<String, dynamic>> users = await db.query(
      'user',
      where: 'is_logged_in = ?',  // Add this column to track logged in status
      whereArgs: [1],
      limit: 1
    );
    
    if (users.isNotEmpty) {
      setState(() {
        _userName = users.first['name'] ?? 'User';
        _userEmail = users.first['email'] ?? '';
      });
    } else {
      // Not logged in, use "Guest" as the name
      setState(() {
        _userName = 'Guest';
        _userEmail = '';
      });
    }
  }

  Future<void> _loadCurrency() async {
    final currency = await _dbHelper.getCurrency();
    if (mounted) {
      setState(() {
        _currencySymbol = getCurrencySymbol(currency);
      });
    }
  }

  Future<void> _loadLanguage() async {
    final language = await _dbHelper.getLanguage();
    await _languageService.setLanguage(language);
    if (mounted) {
      setState(() {});
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(_languageService.translate('logout')),
          content: Text(_languageService.translate('logoutConfirm')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_languageService.translate('cancel')),
            ),
            TextButton(
              onPressed: () async {
                final db = await _dbHelper.database;
                await db.update(
                  'user',
                  {'is_logged_in': 0},
                  where: 'email = ?',
                  whereArgs: [_userEmail]
                );
                
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const Loginregister()),
                    (Route<dynamic> route) => false,
                  );
                }
              },
              child: Text(_languageService.translate('logout')),
            ),
          ],
        );
      },
    );
  }
  
  // Show transfer dialog when dropping a wallet onto another
  void _showTransferDialog(Map<String, dynamic> sourceWallet, Map<String, dynamic> targetWallet) {
    _transferAmountController.clear();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_languageService.translate('transferFunds')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${_languageService.translate('from')}: ${sourceWallet['name']} ($_currencySymbol${sourceWallet['balance'].toStringAsFixed(2)})",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "${_languageService.translate('to')}: ${targetWallet['name']} ($_currencySymbol${targetWallet['balance'].toStringAsFixed(2)})",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _transferAmountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _languageService.translate('amount'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                prefixText: _currencySymbol,
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_languageService.translate('cancel')),
          ),
          TextButton(
            onPressed: () async {
              // Validate input
              final amountText = _transferAmountController.text;
              if (amountText.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(_languageService.translate('enterAmount')))
                );
                return;
              }
              
              double? amount = double.tryParse(amountText);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(_languageService.translate('enterValidAmount')))
                );
                return;
              }
              
              if (amount > sourceWallet['balance']) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(_languageService.translate('insufficientFunds')))
                );
                return;
              }
              
              // Process transfer
              bool success = await _dbHelper.transferBetweenWallets(
                sourceWallet['id'],
                targetWallet['id'],
                amount
              );
              
              if (mounted) {
                Navigator.pop(context);
                
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_languageService.translate('transferSuccess')))
                  );
                  
                  // Refresh data
                  setState(() {
                    _loadData();
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_languageService.translate('transferFailed')))
                  );
                }
              }
            },
            child: Text(_languageService.translate('transfer')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _languageService.translate('personalFinance'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A237E), Color(0xFF64B5F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
      ),
      drawer: _buildDrawer(),
      body: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark 
              ? Colors.black.withAlpha(179) // 0.7 * 255 ≈ 179
              : Colors.white.withAlpha(179),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Summary Cards - использую ListView вместо Column, чтобы обеспечить скроллинг при необходимости
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SummaryCard(
                      title: _languageService.translate('income'),
                      amount: '$_currencySymbol${_totalIncome.toStringAsFixed(2)}',
                      color: Colors.green,
                      icon: Icons.arrow_upward,
                    ),
                    const SizedBox(height: 8),
                    SummaryCard(
                      title: _languageService.translate('expenses'),
                      amount: '$_currencySymbol${_totalExpenses.toStringAsFixed(2)}',
                      color: Colors.red,
                      icon: Icons.arrow_downward,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              
              // Wallet Cards with Drag & Drop
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Balance Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _languageService.translate('balance'),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          '$_currencySymbol${_balance.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Using Wrap instead of SingleChildScrollView
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _walletsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}'));
                        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_languageService.translate('noWallets')),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: () => _showAddWalletDialog(),
                                  icon: const Icon(Icons.add),
                                  label: Text(
                                    _languageService.translate('addWallet'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          );
                        }
                        
                        final wallets = snapshot.data!;
                        return Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: wallets.map((wallet) {
                            return _buildDraggableWalletCard(wallet, wallets);
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      // Floating Action Button
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddTransactionScreen()),
          );

          if (result == true) {
            setState(() {
              _loadData(); // Refresh transactions and summary data
            });
          }
        },
        backgroundColor: const Color.fromARGB(255, 124, 87, 188),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
  
  // Build a wallet card
  Widget _buildWalletCard(Map<String, dynamic> wallet, {bool isTargeted = false}) {
    final balance = wallet['balance'] as double;
    final double cardSize = 85.0; // Even smaller for better grid layout
    
    return Card(
      elevation: isTargeted ? 8 : 2,
      margin: const EdgeInsets.all(4),
      shape: const CircleBorder(),
      child: Container(
        width: cardSize,
        height: cardSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: isTargeted ? Border.all(
            color: Colors.deepPurple,
            width: 2,
          ) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              wallet['name'] as String,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '${_currencySymbol}${balance.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Build a draggable wallet card
  Widget _buildDraggableWalletCard(Map<String, dynamic> wallet, List<Map<String, dynamic>> allWallets) {
    final balance = wallet['balance'] as double;
    final double cardSize = 85.0; // Even smaller for better grid layout
    
    return LongPressDraggable<Map<String, dynamic>>(
      data: wallet,
      delay: const Duration(milliseconds: 0),
      dragAnchorStrategy: (draggable, context, position) {
        return Offset(cardSize / 2, cardSize / 2);
      },
      feedback: Material(
        elevation: 8.0,
        shape: const CircleBorder(),
        color: Colors.transparent,
        child: Container(
          width: cardSize,
          height: cardSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).cardColor.withOpacity(0.9),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                wallet['name'] as String,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                '${_currencySymbol}${balance.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildWalletCard(wallet),
      ),
      child: DragTarget<Map<String, dynamic>>(
        onWillAcceptWithDetails: (data) => data.data['id'] != wallet['id'],
        onAcceptWithDetails: (details) {
          _showTransferDialog(details.data, wallet);
        },
        builder: (context, candidateData, rejectedData) {
          return _buildWalletCard(wallet, 
            isTargeted: candidateData.isNotEmpty
          );
        },
      ),
    );
  }

  // Widget to display each transaction
  Widget _buildTransactionTile(Map<String, dynamic> transaction) {
    bool isIncome = transaction['type'] == 'income';
    bool isTransfer = transaction['type'] == 'transfer';
    final theme = Theme.of(context);
    
    // Get wallet name asynchronously
    Widget buildWalletInfo() {
      if (transaction['wallet_id'] == null) {
        return const SizedBox.shrink();
      }
      
      return FutureBuilder<List<Map<String, dynamic>>>(
        future: _dbHelper.getAllWallets(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox.shrink();
          }
          
          final wallets = snapshot.data!;
          final walletId = transaction['wallet_id'] as int;
          
          // Find matching wallet
          final wallet = wallets.firstWhere(
            (w) => w['id'] == walletId,
            orElse: () => {'name': 'Unknown'},
          );
          
          return Text(
            wallet['name'] as String,
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          );
        },
      );
    }
    
    String description = transaction['description'] ?? '';
    if (description.isEmpty) {
      description = _languageService.translate('noDescription');
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: isTransfer 
              ? Colors.blue[100] 
              : (isIncome ? Colors.green[100] : Colors.red[100]),
          child: Icon(
            isTransfer 
                ? Icons.swap_horiz 
                : (isIncome ? Icons.arrow_downward : Icons.arrow_upward),
            color: isTransfer 
                ? Colors.blue 
                : (isIncome ? Colors.green : Colors.red),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                isTransfer
                    ? _languageService.translate('transfer')
                    : _languageService.translate(transaction['category'] ?? 'Others'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ),
            buildWalletInfo(),
          ],
        ),
        subtitle: Text(
          '$description - ${transaction['date']}'.trim(),
          style: TextStyle(
            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
        trailing: Text(
          '$_currencySymbol${transaction['amount'].toStringAsFixed(2)}',
          style: TextStyle(
            color: isTransfer 
                ? Colors.blue 
                : (transaction['type'] == 'expense' ? Colors.red : Colors.green),
            fontWeight: FontWeight.bold,
          ),
        ),
        onTap: () => _showTransactionActions(context, transaction),
      ),
    );
  }

  // Show options for Edit and Delete
  void _showTransactionActions(
      BuildContext context, Map<String, dynamic> transaction) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(_languageService.translate('editTransaction')),
          content: Text(_languageService.translate('whatWouldYouLikeToDo')),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _editTransaction(transaction);
              },
              child: Text(_languageService.translate('edit')),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _deleteTransaction(transaction['id']);
              },
              child: Text(
                _languageService.translate('delete'),
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  // Edit transaction
  void _editTransaction(Map<String, dynamic> transaction) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(transaction: transaction),
      ),
    );

    if (result == true) {
      setState(() {
        _loadData(); // Refresh transactions and summary data
      });
    }
  }

  // Delete transaction
  Future<void> _deleteTransaction(int transactionId) async {
    bool confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Transaction"),
        content:
            const Text("Are you sure you want to delete this transaction?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmDelete) {
      try {
        await _dbHelper.deleteTransaction(transactionId);
        setState(() {
          _loadData(); // Refresh transactions and summary data
        });
      } catch (e) {
        print("Error deleting transaction: $e");
      }
    }
  }

  // Drawer Widget
  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.deepPurple),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.account_circle, size: 50, color: Colors.white),
                const SizedBox(height: 10),
                Text(
                  _userName,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                Text(
                  _userEmail,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.account_box),
            title: Text(_languageService.translate('account')),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.category),
            title: Text(_languageService.translate('category')),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CategoryScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(_languageService.translate('logout')),
            onTap: _showLogoutDialog,
          ),
        ],
      ),
    );
  }

  void _showAddWalletDialog() {
    final walletNameController = TextEditingController();
    final balanceController = TextEditingController(text: "0");
    final walletTypes = ['Cash', 'Card'];
    String selectedType = 'Cash';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(_languageService.translate('addWallet')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: walletNameController,
                    decoration: InputDecoration(
                      labelText: _languageService.translate('walletName'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: balanceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: _languageService.translate('initialBalance'),
                      border: const OutlineInputBorder(),
                      prefixText: _currencySymbol,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: InputDecoration(
                      labelText: _languageService.translate('walletType'),
                      border: const OutlineInputBorder(),
                    ),
                    items: walletTypes.map((type) {
                      return DropdownMenuItem<String>(
                        value: type,
                        child: Text(_languageService.translate(type.toLowerCase())),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedType = value;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(_languageService.translate('cancel')),
                ),
                TextButton(
                  onPressed: () async {
                    // Validate inputs
                    if (walletNameController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(_languageService.translate('enterWalletName')))
                      );
                      return;
                    }

                    // Parse balance with fallback to 0.0
                    double balance = 0.0;
                    try {
                      balance = double.parse(balanceController.text);
                    } catch (e) {
                      print("Couldn't parse balance: $e, using default 0.0");
                    }

                    // Create wallet with explicit values for all fields
                    final wallet = {
                      'name': walletNameController.text,
                      'balance': balance,
                      'type': selectedType,
                    };

                    try {
                      print("Attempting to insert wallet: $wallet");
                      final result = await _dbHelper.insertWallet(wallet);
                      print("Insert result: $result");
                      
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(_languageService.translate('walletCreated')))
                        );

                        // Refresh wallets
                        setState(() {
                          _loadData();
                        });
                      }
                    } catch (e) {
                      print("Error creating wallet: $e");
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'))
                        );
                      }
                    }
                  },
                  child: Text(_languageService.translate('add')),
                ),
              ],
            );
          }
        );
      },
    );
  }
}

