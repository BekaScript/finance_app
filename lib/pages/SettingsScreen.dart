import 'package:flutter/material.dart';
import 'package:personal_finance/database/database_helper.dart';
import 'package:personal_finance/services/language_service.dart';
import 'package:personal_finance/services/theme_service.dart';
import 'package:personal_finance/pages/LogingRegister.dart';
import 'package:personal_finance/services/csv_service.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:cross_file/cross_file.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late LanguageService _languageService;
  final ThemeService _themeService = ThemeService();
  final CsvService _csvService = CsvService();
  bool _isDarkMode = false;
  String _selectedCurrency = 'USD';
  String _selectedLanguage = 'en';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    print('SettingsScreen initialized');
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _languageService = Provider.of<LanguageService>(context, listen: false);
  }

  Future<void> _loadSettings() async {
    print('SettingsScreen: Loading settings...');
    final currency = await _dbHelper.getCurrency();
    final language = await _languageService.getCurrentLanguage();
    final isDarkMode = await _dbHelper.getDarkMode();
    print('SettingsScreen: Current dark mode setting: $isDarkMode');
    if (mounted) {
      setState(() {
        _selectedCurrency = currency;
        _selectedLanguage = language;
        _isDarkMode = isDarkMode;
      });
    }
  }

  Future<void> _selectCurrency(String? currency) async {
    if (currency != null) {
      await _dbHelper.setCurrency(currency);
      if (mounted) {
        setState(() {
          _selectedCurrency = currency;
        });
      }
      // Force refresh of all screens that show currency
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Currency updated successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _toggleTheme() async {
    print('SettingsScreen: Toggling theme');
    final newValue = !_isDarkMode;
    await _themeService.toggleTheme();
    if (mounted) {
      setState(() {
        _isDarkMode = newValue;
      });
      print('SettingsScreen: Theme toggled to: $newValue');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _languageService.translate('settings'),
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
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.black.withAlpha(179)
              : Colors.white.withAlpha(179),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              // Theme Toggle
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: SwitchListTile.adaptive(
                  title: Text(_languageService.translate('darkMode'),
                      style: const TextStyle(fontSize: 16)),
                  subtitle: Text(_isDarkMode
                      ? _languageService.translate('enabled')
                      : _languageService.translate('disabled')),
                  value: _isDarkMode,
                  onChanged: (value) => _toggleTheme(),
                  secondary:
                      const Icon(Icons.dark_mode, color: Colors.deepPurple),
                ),
              ),

              const SizedBox(height: 16),

              // Currency Selection
              _buildCurrencySelector(),

              const SizedBox(height: 16),

              // Language Selection
              ListTile(
                leading: const Icon(Icons.language, color: Colors.deepPurple),
                title: Text(_languageService.translate('selectLanguage')),
                subtitle: DropdownButtonFormField<String>(
                  value: _selectedLanguage,
                  onChanged: (String? newValue) async {
                    if (newValue != null) {
                      await _languageService.setLanguage(newValue);
                      if (mounted) {
                        setState(() {
                          _selectedLanguage = newValue;
                        });
                        // Show a snackbar to confirm the language change
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(_languageService
                                  .translate('languageUpdated')),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      }
                    }
                  },
                  items: [
                    DropdownMenuItem(
                      value: 'en',
                      child: Text(_languageService.translate('english')),
                    ),
                    DropdownMenuItem(
                      value: 'ru',
                      child: Text(_languageService.translate('russian')),
                    ),
                    DropdownMenuItem(
                      value: 'ky',
                      child: Text(_languageService.translate('kyrgyz')),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Reset Data Button
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const Icon(Icons.restore, color: Colors.orange),
                  title: Text(
                    _languageService.translate('resetData'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    _languageService.translate('resetDataDescription'),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withOpacity(0.6),
                    ),
                  ),
                  onTap: _showResetConfirmation,
                ),
              ),

              // CSV Export Button
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const Icon(Icons.file_download, color: Colors.green),
                  title: Text(
                    _languageService.translate('exportData'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    _languageService.translate('exportDataDescription'),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withOpacity(0.6),
                    ),
                  ),
                  onTap: _showExportOptionsDialog,
                ),
              ),

              const SizedBox(height: 16),

              // Login/Register button
              ListTile(
                leading: const Icon(Icons.login),
                title: Text(_languageService.translate('loginRegister')),
                onTap: () {
                  Navigator.pushNamed(context, '/login');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Currency selection
  Widget _buildCurrencySelector() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.currency_exchange, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Text(
                  _languageService.translate('selectCurrency'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCurrency,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onChanged: (String? value) {
                if (value != null) {
                  _showExchangeRateDialog(value);
                }
              },
              items: ['USD', 'EUR', 'INR', 'KGS'].map((currency) {
                return DropdownMenuItem<String>(
                  value: currency,
                  child: Row(
                    children: [
                      _getCurrencyIcon(currency),
                      const SizedBox(width: 8),
                      Text(_languageService.translate(currency)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // Helper to get currency icon
  Widget _getCurrencyIcon(String currency) {
    IconData iconData;
    Color iconColor;

    switch (currency) {
      case 'USD':
        iconData = Icons.attach_money;
        iconColor = Colors.green;
        break;
      case 'EUR':
        iconData = Icons.euro;
        iconColor = Colors.blue;
        break;
      case 'INR':
        iconData = Icons.currency_rupee;
        iconColor = Colors.orange;
        break;
      case 'KGS':
        iconData = Icons.money;
        iconColor = Colors.purple;
        break;
      default:
        iconData = Icons.money;
        iconColor = Colors.grey;
    }

    return Icon(iconData, color: iconColor);
  }

  // Show exchange rate dialog when selecting currency
  Future<void> _showExchangeRateDialog(String currency) async {
    if (currency == _selectedCurrency) return;

    // Get current exchange rate for this currency
    double currentRate = await _dbHelper.getExchangeRate(currency);
    final rateController = TextEditingController(text: currentRate.toString());

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_languageService.translate('setExchangeRate')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1 ${_languageService.translate(currency)} = ? KGS'),
            const SizedBox(height: 16),
            TextField(
              controller: rateController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: _languageService.translate('exchangeRate'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_languageService.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              // Parse the rate and validate
              double? rate = double.tryParse(rateController.text);
              if (rate != null && rate > 0) {
                // Update the exchange rate
                await _dbHelper.setExchangeRate(currency, rate);
                // Update the currency
                await _setCurrency(currency);
                // Close dialog
                if (mounted) {
                  Navigator.pop(context);
                  // Show confirmation
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _languageService.translate('currencyRateUpdated'),
                        style: const TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } else {
                // Show error
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_languageService.translate('invalidRate')),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text(_languageService.translate('save')),
          ),
        ],
      ),
    );
  }

  // Set currency in database
  Future<void> _setCurrency(String currency) async {
    await _dbHelper.setCurrency(currency);
    setState(() {
      _selectedCurrency = currency;
    });
  }

  // Show reset confirmation dialog
  Future<void> _showResetConfirmation() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(_languageService.translate('resetDataConfirmation')),
          content: Text(_languageService.translate('areYouSureResetData')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_languageService.translate('cancel')),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _resetData();
              },
              child: Text(
                _languageService.translate('reset'),
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  // Reset data
  Future<void> _resetData() async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Text(_languageService.translate('resettingData')),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Call the database helper reset method
      final success = await _dbHelper.resetTransactionData();

      if (mounted) {
        if (success) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_languageService.translate('resetDataSuccess')),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_languageService.translate('resetDataError')),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error resetting data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_languageService.translate('resetDataError')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show logout confirmation dialog
  Future<void> _showLogoutConfirmation() async {
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
                Navigator.pop(context);
                // Используем новый метод logoutUser
                final success = await _dbHelper.logoutUser();
                if (success) {
                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (context) => const Loginregister()),
                      (Route<dynamic> route) => false,
                    );
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text(_languageService.translate('logoutFailed'))),
                    );
                  }
                }
              },
              child: Text(_languageService.translate('logout')),
            ),
          ],
        );
      },
    );
  }

  // Show export options dialog
  Future<void> _showExportOptionsDialog() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(_languageService.translate('exportData')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.calendar_month),
                title:
                    Text(_languageService.translate('exportForCurrentMonth')),
                onTap: () {
                  Navigator.pop(context);
                  _exportCurrentMonth();
                },
              ),
              ListTile(
                leading: const Icon(Icons.date_range),
                title: Text(_languageService.translate('exportForCustomRange')),
                onTap: () {
                  Navigator.pop(context);
                  _showDateRangeDialog();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_languageService.translate('cancel')),
            ),
          ],
        );
      },
    );
  }

  // Export for current month
  Future<void> _exportCurrentMonth() async {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

    await _exportData(firstDayOfMonth, lastDayOfMonth);
  }

  // Show dialog to select custom date range
  Future<void> _showDateRangeDialog() async {
    final now = DateTime.now();
    DateTime startDate = DateTime(now.year, now.month, 1);
    DateTime endDate = DateTime(now.year, now.month, now.day);

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(_languageService.translate('selectDateRange')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title:
                          Text(_languageService.translate('selectStartDate')),
                      subtitle:
                          Text(DateFormat('MMM dd, yyyy').format(startDate)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: startDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (pickedDate != null) {
                          setState(() {
                            startDate = pickedDate;
                            // Ensure end date is not before start date
                            if (endDate.isBefore(startDate)) {
                              endDate = startDate;
                            }
                          });
                        }
                      },
                    ),
                    ListTile(
                      title: Text(_languageService.translate('selectEndDate')),
                      subtitle:
                          Text(DateFormat('MMM dd, yyyy').format(endDate)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: endDate,
                          firstDate: startDate,
                          lastDate: DateTime.now(),
                        );
                        if (pickedDate != null) {
                          setState(() {
                            endDate = pickedDate;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(_languageService.translate('cancel')),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _exportData(startDate, endDate);
                  },
                  child: Text(_languageService.translate('exportToCsv')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Export data for the selected date range
  Future<void> _exportData(DateTime startDate, DateTime endDate) async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Text(_languageService.translate('exporting')),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Get currency
      final currency = await _dbHelper.getCurrency();

      // Export data
      final filePath = await _csvService.exportTransactionHistory(
        startDate,
        endDate,
        currency,
      );

      if (filePath.isNotEmpty) {
        _showExportSuccessDialog(filePath);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_languageService.translate('exportError')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error exporting data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_languageService.translate('exportError')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show export success dialog
  Future<void> _showExportSuccessDialog(String filePath) async {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(_languageService.translate('exportComplete')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_languageService.translate('exportSuccess')),
              const SizedBox(height: 8),
              Text(
                '${_languageService.translate('fileSaved')}\n$filePath',
                style: const TextStyle(fontSize: 12),
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
                _shareFile(filePath);
              },
              child: Text(_languageService.translate('shareFile')),
            ),
          ],
        );
      },
    );
  }

  // Share the exported file
  Future<void> _shareFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await Share.shareXFiles([XFile(filePath)],
            text: _languageService.translate('transactionHistory'));
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_languageService.translate('exportError')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error sharing file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
