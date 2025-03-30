import 'package:flutter/material.dart';
import 'package:personal_finance/pages/AddTransactionScreen.dart';
import 'package:personal_finance/database/database_helper.dart';
import 'package:personal_finance/pages/LogingRegister.dart';
import 'package:personal_finance/widgets/summary_card.dart';
import '../utils/currency_utils.dart';
import '../services/language_service.dart';
import '../pages/CategoryScreen.dart';


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
  final LanguageService _languageService = LanguageService();
  
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
      return await _dbHelper.getAllWallets();
    } catch (e) {
      print("Error fetching wallets: $e");
      return [];
    }
  }

  // Fetch summary data (income, expenses, balance)
  Future<void> _fetchSummaryData() async {
    try {
      final db = await dbHelper.database;

      // Get total income
      final incomeResult = await db.rawQuery(
          "SELECT SUM(amount) as total FROM transactions WHERE type = 'income'");
      _totalIncome = incomeResult.first['total'] != null
          ? (incomeResult.first['total'] as num).toDouble()
          : 0.0;

      // Get total expenses
      final expenseResult = await db.rawQuery(
          "SELECT SUM(amount) as total FROM transactions WHERE type = 'expense'");
      _totalExpenses = expenseResult.first['total'] != null
          ? (expenseResult.first['total'] as num).toDouble()
          : 0.0;

      // Calculate balance
      _balance = _totalIncome - _totalExpenses;

      setState(() {}); // Refresh UI
    } catch (e) {
      print("Error fetching summary data: $e");
    }
  }

  // Fetch all transactions
  Future<List<Map<String, dynamic>>> _fetchTransactions() async {
    try {
      final db = await dbHelper.database;
      return await db.query('transactions', orderBy: 'date DESC');
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
        child: Column(
          children: [
            // Summary Cards
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  SummaryCard(
                    title: _languageService.translate('income'),
                    amount: '$_currencySymbol${_totalIncome.toStringAsFixed(2)}',
                    color: Colors.green,
                    icon: Icons.arrow_upward,
                  ),
                  const SizedBox(height: 12),
                  SummaryCard(
                    title: _languageService.translate('expenses'),
                    amount: '$_currencySymbol${_totalExpenses.toStringAsFixed(2)}',
                    color: Colors.red,
                    icon: Icons.arrow_downward,
                  ),
                  const SizedBox(height: 12),
                  SummaryCard(
                    title: _languageService.translate('balance'),
                    amount: '$_currencySymbol${_balance.toStringAsFixed(2)}',
                    color: Colors.blue,
                    icon: Icons.account_balance_wallet,
                  ),
                ],
              ),
            ),
            
            // Wallet Cards with Drag & Drop
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _languageService.translate('wallets'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _languageService.translate('dragToTransfer'),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _walletsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Center(
                          child: Text(_languageService.translate('noWallets'))
                        );
                      }
                      
                      final wallets = snapshot.data!;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: wallets.map((wallet) {
                          final balance = wallet['balance'] as double;
                          
                          return _buildDraggableWalletCard(wallet, wallets);
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Recent Transactions
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  setState(() {
                    _loadData(); // Refresh data
                  });
                },
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _transactionsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Text(_languageService.translate('noTransactions'))
                      );
                    }

                    final transactions = snapshot.data!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Text(
                            _languageService.translate('recentTransactions'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: transactions.length,
                            itemBuilder: (context, index) {
                              final transaction = transactions[index];
                              return _buildTransactionTile(transaction);
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
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
  
  // Build a draggable wallet card
  Widget _buildDraggableWalletCard(Map<String, dynamic> wallet, List<Map<String, dynamic>> allWallets) {
    final balance = wallet['balance'] as double;
    
    return LongPressDraggable<Map<String, dynamic>>(
      data: wallet,
      feedback: Material(
        elevation: 4.0,
        borderRadius: BorderRadius.circular(12.0),
        child: Container(
          width: 150,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                wallet['name'] as String,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '$_currencySymbol${balance.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: balance >= 0 ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: _buildWalletCard(wallet),
      ),
      child: DragTarget<Map<String, dynamic>>(
        onWillAccept: (data) => data != null && data['id'] != wallet['id'],
        onAccept: (sourceWallet) {
          // Show transfer dialog when a wallet is dropped onto this one
          _showTransferDialog(sourceWallet, wallet);
        },
        builder: (context, candidateData, rejectedData) {
          return _buildWalletCard(wallet, 
            isTargeted: candidateData.isNotEmpty
          );
        },
      ),
    );
  }
  
  // Build a wallet card
  Widget _buildWalletCard(Map<String, dynamic> wallet, {bool isTargeted = false}) {
    final balance = wallet['balance'] as double;
    
    return Card(
      elevation: isTargeted ? 8 : 2,
      margin: const EdgeInsets.only(right: 4, bottom: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isTargeted ? BorderSide(
          color: Colors.deepPurple,
          width: 2,
        ) : BorderSide.none,
      ),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              wallet['name'] as String,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '$_currencySymbol${balance.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: balance >= 0 ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
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
}

