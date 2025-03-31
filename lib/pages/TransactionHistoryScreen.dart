import 'package:flutter/material.dart';
import 'package:personal_finance/database/database_helper.dart';
import 'AddTransactionScreen.dart';
import '../utils/currency_utils.dart';
import '../services/language_service.dart';
import '../services/csv_service.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  _TransactionHistoryScreenState createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  String _currencySymbol = '\$';
  String _currency = 'USD';
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final CsvService _csvService = CsvService();
  List<Map<String, dynamic>> _transactions = [];
  String _searchQuery = "";
  String _filterType = "All";
  final LanguageService _languageService = LanguageService();

  // Date range for exports
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  bool _isExporting = false;

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
    try {
      final transactions = await _dbHelper.getTransactions();

      print("Загружено ${transactions.length} транзакций в историю транзакций");
      if (transactions.isNotEmpty) {
        print("Первая транзакция: ${transactions.first}");
      }

      setState(() {
        _transactions = transactions;
      });
    } catch (e) {
      print("Ошибка при загрузке транзакций: $e");
      setState(() {
        _transactions = [];
      });
    }
  }

  Future<void> _loadCurrency() async {
    final currency = await _dbHelper.getCurrency();
    if (mounted) {
      setState(() {
        _currency = currency;
        _currencySymbol = getCurrencySymbol(currency);
      });
    }
  }

  Future<void> _deleteTransaction(int id) async {
    bool confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_languageService.translate('deleteTransaction')),
        content: Text(_languageService.translate('confirmDeleteTransaction')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_languageService.translate('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_languageService.translate('delete'),
                style: const TextStyle(color: Colors.red)),
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
            icon: const Icon(Icons.file_download, color: Colors.white),
            onPressed: () => _showExportDialog(),
            tooltip: _languageService.translate('exportToCsv'),
          ),
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: () => _showFilterModal(),
          ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A237E), Color(0xFF64B5F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.black.withAlpha(179)
              : Colors.white.withAlpha(179),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                _buildSearchBar(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadTransactions,
                    child: filteredTransactions.isEmpty
                        ? Center(
                            child: Text(_languageService
                                .translate('noTransactionFound')))
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
            if (_isExporting)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
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
    final theme = Theme.of(context);
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
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          subtitle: Text(
            '${_languageService.translate(transaction['description'])} - ${transaction['date']}',
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
          ),
          trailing: Text(
            transaction['type'] == 'expense'
                ? '-$_currencySymbol${transaction['amount'].toStringAsFixed(2)}'
                : '+$_currencySymbol${transaction['amount'].toStringAsFixed(2)}',
            style: TextStyle(
              color:
                  transaction['type'] == 'expense' ? Colors.red : Colors.green,
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
          title: Text(_languageService.translate('transactionActions')),
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
              child: Text(_languageService.translate('delete'),
                  style: const TextStyle(color: Colors.red)),
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
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _filterType,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                items: [
                  DropdownMenuItem(
                      value: "All",
                      child: Text(_languageService.translate('all'))),
                  DropdownMenuItem(
                      value: "Income",
                      child: Text(_languageService.translate('income'))),
                  DropdownMenuItem(
                      value: "Expense",
                      child: Text(_languageService.translate('expenses'))),
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

  // Show dialog to export transactions to CSV
  void _showExportDialog() {
    final DateFormat dateFormat = DateFormat('MMM dd, yyyy');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: Text(_languageService.translate('exportToCsv')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_languageService.translate('selectDateRange')),
                const SizedBox(height: 16),

                // Start date picker
                ListTile(
                  title: Text(_languageService.translate('startDate')),
                  subtitle: Text(dateFormat.format(_startDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _startDate,
                      firstDate: DateTime(2020),
                      lastDate: _endDate,
                    );
                    if (picked != null) {
                      setState(() {
                        _startDate = picked;
                      });
                    }
                  },
                ),

                // End date picker
                ListTile(
                  title: Text(_languageService.translate('endDate')),
                  subtitle: Text(dateFormat.format(_endDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _endDate,
                      firstDate: _startDate,
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (picked != null) {
                      setState(() {
                        _endDate = picked;
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
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _exportTransactions();
                },
                child: Text(_languageService.translate('export')),
              ),
            ],
          );
        });
      },
    );
  }

  // Export transactions to CSV
  Future<void> _exportTransactions() async {
    try {
      setState(() {
        _isExporting = true;
      });

      final filePath = await _csvService.exportTransactionHistory(
          _startDate, _endDate, _currency);

      setState(() {
        _isExporting = false;
      });

      if (filePath.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_languageService.translate('exportFailed'))),
          );
        }
        return;
      }

      // Show success message and share options
      if (mounted) {
        _showExportSuccessDialog(filePath);
      }
    } catch (e) {
      setState(() {
        _isExporting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // Show success dialog with share option
  void _showExportSuccessDialog(String filePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_languageService.translate('exportSuccess')),
        content: Text(_languageService
            .translate('fileSavedTo')
            .replaceAll('{path}', filePath)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_languageService.translate('ok')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _shareExportedFile(filePath);
            },
            child: Text(_languageService.translate('share')),
          ),
        ],
      ),
    );
  }

  // Share the exported file
  Future<void> _shareExportedFile(String filePath) async {
    try {
      final file = File(filePath);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: _languageService.translate('transactionHistory'),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing file: $e')),
        );
      }
    }
  }
}
