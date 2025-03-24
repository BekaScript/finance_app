import 'package:flutter/material.dart';
import 'package:personal_finance/pages/AddTransactionScreen.dart';
import 'package:personal_finance/database/database_helper.dart';
import 'package:personal_finance/pages/LogingRegister.dart';
import 'package:personal_finance/widgets/summary_card.dart';
import '../utils/currency_utils.dart';
import '../services/language_service.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late DatabaseHelper dbHelper;
  late Future<List<Map<String, dynamic>>> _transactionsFuture;

  double _totalIncome = 0.0;
  double _totalExpenses = 0.0;
  double _balance = 0.0;

  // Add user data state variables
  String _userName = '';
  String _userEmail = '';
  String _currencySymbol = '\$';
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final LanguageService _languageService = LanguageService();

  @override
  void initState() {
    super.initState();
    dbHelper = DatabaseHelper();
    _loadCurrency();
    _loadData();
    _loadUserData();
    _loadLanguage();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadCurrency();
  }

  // Load transactions and summary data
  void _loadData() {
    _transactionsFuture = _fetchTransactions();
    _fetchSummaryData();
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
              colors: [Colors.blueAccent, Colors.purpleAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
      ),
      drawer: _buildDrawer(),
      backgroundColor: Colors.white,
      body: Column(
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
                  return ListView.builder(
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final transaction = transactions[index];
                      return _buildTransactionTile(transaction);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),

      // Floating Action Button
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddTransactionScreen()),
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

  // Widget to display each transaction
  Widget _buildTransactionTile(Map<String, dynamic> transaction) {
    bool isIncome = transaction['type'] == 'income';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: isIncome ? Colors.green[100] : Colors.red[100],
          child: Icon(
            isIncome ? Icons.arrow_downward : Icons.arrow_upward,
            color: isIncome ? Colors.green : Colors.red,
          ),
        ),
        title: Text(
          _languageService.translate(transaction['category'] ?? 'Others'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${_languageService.translate(transaction['description'])} - ${transaction['date']}',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        trailing: Text(
          '$_currencySymbol${transaction['amount'].toStringAsFixed(2)}',
          style: TextStyle(
            color: transaction['type'] == 'expense' ? Colors.red : Colors.green,
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
        final db = await dbHelper.database;
        await db.delete('transactions',
            where: 'id = ?', whereArgs: [transactionId]);
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
              // Navigate to settings (implement later)
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

