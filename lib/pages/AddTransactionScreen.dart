// ignore: file_names
import 'package:flutter/material.dart';
import 'package:nur_budget/database/database_helper.dart';
import 'package:nur_budget/services/language_service.dart';

class AddTransactionScreen extends StatefulWidget {
  final Map<String, dynamic>? transaction; // Accepts transaction for editing

  // ignore: use_super_parameters
  const AddTransactionScreen({Key? key, this.transaction}) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _AddTransactionScreenState createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final LanguageService _languageService = LanguageService();

  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  String _type = 'expense'; // Default to expense
  String? _category;
  int? _walletId;
  DateTime _selectedDate = DateTime.now();

  // Lists to hold data from the database
  List<Map<String, dynamic>> _incomeCategories = [];
  List<Map<String, dynamic>> _expenseCategories = [];
  List<Map<String, dynamic>> _currentCategories =
      []; // Categories for the current type
  List<Map<String, dynamic>> _wallets = []; // Available wallets

  @override
  void initState() {
    super.initState();

    // Initialize controllers
    _amountController = TextEditingController();
    _descriptionController = TextEditingController();

    // Load data from the database
    _loadCategories();
    _loadWallets();

    // If editing, prefill form fields
    if (widget.transaction != null) {
      _amountController.text = widget.transaction!['amount'].toString();
      _descriptionController.text = widget.transaction!['description'] ?? '';
      _type = widget.transaction!['type'];
      _category = widget.transaction!['category'];
      _walletId = widget.transaction!['wallet_id'];
      _selectedDate = DateTime.parse(widget.transaction!['date']);
    }
  }

  Future<void> _loadCategories() async {
    // Load income categories
    _incomeCategories = await _dbHelper.getCategories('income');

    // Load expense categories
    _expenseCategories = await _dbHelper.getCategories('expense');

    // Set current categories based on the selected type
    _updateCurrentCategories();

    // Set default category if needed
    if (_category == null && _currentCategories.isNotEmpty) {
      _category = _currentCategories.first['name'];
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadWallets() async {
    // Load wallets
    _wallets = await _dbHelper.getAllWallets();

    // Set default wallet if needed
    if (_walletId == null && _wallets.isNotEmpty) {
      _walletId = _wallets.first['id'] as int;
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _updateCurrentCategories() {
    _currentCategories =
        _type == 'income' ? _incomeCategories : _expenseCategories;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveTransaction() async {
    if (_formKey.currentState!.validate()) {
      final transactionData = {
        'amount': double.parse(_amountController.text),
        'description': _descriptionController.text.trim(),
        'type': _type,
        'category': _category ??
            (_currentCategories.isNotEmpty
                ? _currentCategories.first['name']
                : 'Others'),
        'wallet_id': _walletId,
        'date': _selectedDate
            .toIso8601String()
            .split('T')[0], // Только дата без времени
      };

      try {
        if (widget.transaction == null) {
          // Insert new transaction
          await _dbHelper.insertTransaction(transactionData);
        } else {
          // Update existing transaction
          await _dbHelper.updateTransaction(
            transactionData,
            widget.transaction!['id'],
          );
        }

        // ignore: use_build_context_synchronously
        Navigator.pop(context, true); // Return success
      } catch (e) {
        print('Error saving transaction: $e');
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    String langCode = await _languageService.getCurrentLanguage();

    // Map language codes to Flutter's MaterialLocalizations
    Locale locale;
    switch (langCode) {
      case 'ru':
        locale = const Locale('ru', 'RU');
        break;
      case 'ky':
        // Flutter might not have built-in support for Kyrgyz
        // Fallback to Russian which is similar
        locale = const Locale('ru', 'RU');
        break;
      default:
        locale = const Locale('en', 'US');
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: locale,
      helpText: _languageService.translate('selectDate'),
      cancelText: _languageService.translate('cancel'),
      confirmText: _languageService.translate('save'),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.transaction != null
              ? _languageService.translate('editTransaction')
              : _languageService.translate('addTransaction'),
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
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Amount Field
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: _languageService.translate('amount'),
                  prefixIcon:
                      const Icon(Icons.attach_money, color: Colors.blueAccent),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return _languageService.translate('enterAmount');
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return _languageService.translate('enterValidAmount');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Description Field (Optional)
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText:
                      '${_languageService.translate('description')} (${_languageService.translate('optional')})',
                  prefixIcon:
                      const Icon(Icons.description, color: Colors.blueAccent),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
                // No validator since description is optional
              ),
              const SizedBox(height: 20),

              // Type Dropdown (replaced with Segmented Button)
              Center(
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: SegmentedButton<String>(
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith<Color>(
                          (Set<WidgetState> states) {
                            if (states.contains(WidgetState.selected)) {
                              return _type == 'income'
                                  ? Colors.green.shade100
                                  : Colors.red.shade100;
                            }
                            return Colors.transparent;
                          },
                        ),
                        foregroundColor: WidgetStateProperty.resolveWith<Color>(
                          (Set<WidgetState> states) {
                            if (states.contains(WidgetState.selected)) {
                              return _type == 'income'
                                  ? Colors.green.shade800
                                  : Colors.red.shade800;
                            }
                            return Colors.grey.shade700;
                          },
                        ),
                      ),
                      segments: [
                        ButtonSegment<String>(
                          value: 'income',
                          label: Text(_languageService.translate('income')),
                          icon: const Icon(Icons.arrow_downward),
                        ),
                        ButtonSegment<String>(
                          value: 'expense',
                          label: Text(_languageService.translate('expense')),
                          icon: const Icon(Icons.arrow_upward),
                        ),
                      ],
                      selected: {_type},
                      onSelectionChanged: (Set<String> newSelection) {
                        if (newSelection.isNotEmpty) {
                          setState(() {
                            _type = newSelection.first;
                            _updateCurrentCategories();
                            // Reset category when changing type
                            _category = _currentCategories.isNotEmpty
                                ? _currentCategories.first['name']
                                : null;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Category Dropdown
              DropdownButtonFormField<String>(
                value: _category,
                decoration: InputDecoration(
                  labelText: _languageService.translate('category'),
                  prefixIcon:
                      const Icon(Icons.category, color: Colors.blueAccent),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
                items: _currentCategories.map((category) {
                  return DropdownMenuItem<String>(
                    value: category['name'],
                    child: Text(category['name']),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _category = value;
                    });
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return _languageService.translate('selectCategory');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Wallet Dropdown
              DropdownButtonFormField<int>(
                value: _walletId,
                decoration: InputDecoration(
                  labelText: _languageService.translate('wallet'),
                  prefixIcon: const Icon(Icons.account_balance_wallet,
                      color: Colors.blueAccent),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
                items: _wallets.map((wallet) {
                  return DropdownMenuItem<int>(
                    value: wallet['id'] as int,
                    child: Text('${wallet['name']} (${wallet['balance']})'),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _walletId = value;
                    });
                  }
                },
                validator: (value) {
                  if (value == null) {
                    return _languageService.translate('selectWallet');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Date Picker
              ListTile(
                title: Text(
                  _languageService.translate('date'),
                  style: const TextStyle(color: Colors.blueAccent),
                ),
                subtitle: Text(
                  _selectedDate.toLocal().toString().split(' ')[0],
                  style: const TextStyle(fontSize: 16),
                ),
                trailing:
                    const Icon(Icons.calendar_today, color: Colors.blueAccent),
                onTap: () => _selectDate(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  side: const BorderSide(color: Colors.blueAccent),
                ),
              ),
              const SizedBox(height: 30),

              // Save/Update Button
              ElevatedButton(
                onPressed: _saveTransaction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
                child: Text(
                  _languageService.translate('save'),
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  _languageService.translate('cancel'),
                  style: const TextStyle(color: Colors.blueAccent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper function for capitalization
extension StringExtension on String {
  String capitalize() => '${this[0].toUpperCase()}${substring(1)}';
}
