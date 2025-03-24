import 'package:flutter/material.dart';
import 'package:personal_finance/database/database_helper.dart';
import 'AddTransactionScreen.dart';
import '../utils/currency_utils.dart';
import '../services/language_service.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  _TransactionHistoryScreenState createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  String _currencySymbol = '\$';
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _transactions = [];
  String _searchQuery = "";
  String _filterType = "All";
  final LanguageService _languageService = LanguageService();

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    _loadCurrency();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadCurrency();
  }

  Future<void> _loadTransactions() async {
    final db = await _dbHelper.database;
    final transactions = await db.query('transactions', orderBy: 'date DESC');
    setState(() {
      _transactions = transactions;
    });
  }

  Future<void> _loadCurrency() async {
    final currency = await _dbHelper.getCurrency();
    if (mounted) {
      setState(() {
        _currencySymbol = getCurrencySymbol(currency);
      });
    }
  }

  Future<void> _deleteTransaction(int id) async {
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
      final db = await _dbHelper.database;
      await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
      _loadTransactions();
    }
  }

  // ignore: unused_element
  void _filterTransactions() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> filteredTransactions =
        _transactions.where((transaction) {
      final matchesSearch = transaction['description']
          .toLowerCase()
          .contains(_searchQuery.toLowerCase());
      final matchesFilter = _filterType == "All" ||
          transaction['type'] == _filterType.toLowerCase();
      return matchesSearch && matchesFilter;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _languageService.translate('history'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: () => _showFilterModal(),
          ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blueAccent, Colors.purpleAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadTransactions,
              child: filteredTransactions.isEmpty
                  ? const Center(child: Text("No transactions found"))
                  : ListView.builder(
                      itemCount: filteredTransactions.length,
                      itemBuilder: (context, index) {
                        final transaction = filteredTransactions[index];
                        return _buildTransactionCard(transaction);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        decoration: InputDecoration(
          labelText: _languageService.translate('searchTransactions'),
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _searchQuery = "";
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      elevation: 3,
      child: Dismissible(
        key: Key(transaction['id'].toString()),
        direction: DismissDirection.endToStart,
        background: Container(
          padding: const EdgeInsets.only(right: 20),
          color: Colors.red,
          alignment: Alignment.centerRight,
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        confirmDismiss: (direction) async {
          await _deleteTransaction(transaction['id']);
          return false;
        },
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: transaction['type'] == 'income'
                ? Colors.green[100]
                : Colors.red[100],
            child: Icon(
              transaction['type'] == 'income'
                  ? Icons.arrow_downward
                  : Icons.arrow_upward,
              color:
                  transaction['type'] == 'income' ? Colors.green : Colors.red,
            ),
          ),
          title: Text(
            _languageService.translate(transaction['category']),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            '${_languageService.translate(transaction['description'])} - ${transaction['date']}',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          trailing: Text(
            transaction['type'] == 'expense' ? 
              '-$_currencySymbol${transaction['amount'].toStringAsFixed(2)}' :
              '+$_currencySymbol${transaction['amount'].toStringAsFixed(2)}',
            style: TextStyle(
              color: transaction['type'] == 'expense' ? Colors.red : Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
          onTap: () => _showTransactionActions(context, transaction),
        ),
      ),
    );
  }

  void _showTransactionActions(
      BuildContext context, Map<String, dynamic> transaction) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Transaction Actions"),
          content: const Text("What would you like to do?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _editTransaction(transaction);
              },
              child: const Text("Edit"),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _deleteTransaction(transaction['id']);
              },
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _editTransaction(Map<String, dynamic> transaction) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(transaction: transaction),
      ),
    );

    if (result == true) {
      _loadTransactions();
    }
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          height: 200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _languageService.translate('filters'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _filterType,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: [
                  DropdownMenuItem(value: "All", child: Text(_languageService.translate('all'))),
                  DropdownMenuItem(value: "Income", child: Text(_languageService.translate('income'))),
                  DropdownMenuItem(value: "Expense", child: Text(_languageService.translate('expenses'))),
                ],
                onChanged: (value) {
                  setState(() {
                    _filterType = value!;
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
