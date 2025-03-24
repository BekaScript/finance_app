// ignore: file_names
import 'package:flutter/material.dart';
import 'package:personal_finance/database/database_helper.dart';
import 'package:personal_finance/services/language_service.dart';

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
  String _category = 'Others';
  DateTime _selectedDate = DateTime.now();

  // Predefined categories
  final List<String> categories = ['Food', 'Transport', 'Shopping', 'Bills', 'Others'];

  @override
  void initState() {
    super.initState();

    // Initialize controllers
    _amountController = TextEditingController();
    _descriptionController = TextEditingController();

    // If editing, prefill form fields
    if (widget.transaction != null) {
      _amountController.text = widget.transaction!['amount'].toString();
      _descriptionController.text = widget.transaction!['description'];
      _type = widget.transaction!['type'];
      _category = widget.transaction!['category'];
      _selectedDate = DateTime.parse(widget.transaction!['date']);
    }
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
        'description': _descriptionController.text,
        'type': _type,
        'category': _category,
        'date': _selectedDate.toIso8601String(),
      };

      final db = await _dbHelper.database;

      if (widget.transaction == null) {
        // Insert new transaction
        await db.insert('transactions', transactionData);
      } else {
        // Update existing transaction
        await db.update(
          'transactions',
          transactionData,
          where: 'id = ?',
          whereArgs: [widget.transaction!['id']],
        );
      }

      // ignore: use_build_context_synchronously
      Navigator.pop(context, true); // Return success
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
        iconTheme: IconThemeData(color: Colors.white),
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
                      Icon(Icons.attach_money, color: Colors.blueAccent),
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

              // Description Field
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: _languageService.translate('description'),
                  prefixIcon: Icon(Icons.description, color: Colors.blueAccent),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? _languageService.translate('enterDescription')
                    : null,
              ),
              const SizedBox(height: 20),

              // Type Dropdown
              DropdownButtonFormField<String>(
                value: _type,
                decoration: InputDecoration(
                  labelText: _languageService.translate('type'),
                  prefixIcon:
                      Icon(Icons.type_specimen, color: Colors.blueAccent),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
                items: ["income", "expense"].map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(_languageService.translate(type)),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _type = value!),
              ),
              const SizedBox(height: 20),

              // Category Dropdown
              DropdownButtonFormField<String>(
                value: _category,
                decoration: InputDecoration(
                  labelText: _languageService.translate('category'),
                  prefixIcon: Icon(Icons.category, color: Colors.blueAccent),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
                items: categories.map((String category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(_languageService.translate(category)),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _category = value!),
              ),
              const SizedBox(height: 20),

              // Date Picker
              ListTile(
                title: Text(
                  _languageService.translate('date'),
                  style: TextStyle(color: Colors.blueAccent),
                ),
                subtitle: Text(
                  _selectedDate.toLocal().toString().split(' ')[0],
                  style: TextStyle(fontSize: 16),
                ),
                trailing: Icon(Icons.calendar_today, color: Colors.blueAccent),
                onTap: () => _selectDate(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  side: BorderSide(color: Colors.blueAccent),
                ),
              ),
              const SizedBox(height: 30),

              // Save/Update Button
              ElevatedButton(
                onPressed: _saveTransaction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
                child: Text(
                  _languageService.translate('save'),
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  _languageService.translate('cancel'),
                  style: TextStyle(color: Colors.blueAccent),
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
