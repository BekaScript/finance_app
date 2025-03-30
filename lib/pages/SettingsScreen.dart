import 'package:flutter/material.dart';
import 'package:personal_finance/database/database_helper.dart';
import 'package:personal_finance/services/language_service.dart';
import 'package:personal_finance/services/theme_service.dart';
import 'package:personal_finance/pages/AppLockScreen.dart';


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final LanguageService _languageService = LanguageService();
  final ThemeService _themeService = ThemeService();
  bool _isDarkMode = false;
  String _selectedCurrency = 'USD';
  String _selectedLanguage = 'en';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    print('SettingsScreen initialized');
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
                  title: Text(_languageService.translate('darkMode'), style: const TextStyle(fontSize: 16)),
                  subtitle: Text(_isDarkMode ? _languageService.translate('enabled') : _languageService.translate('disabled')),
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
                              content: Text(_languageService.translate('languageUpdated')),
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
              
              // App Lock Setting
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)
                ),
                child: ListTile(
                  leading: const Icon(Icons.lock, color: Colors.deepPurple),
                  title: Text(
                    _languageService.translate('appLock'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    _languageService.translate('appLockSubtitle'),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                    ),
                  ),
                  onTap: () => _navigateToAppLockScreen(),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Logout Button
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)
                ),
                child: ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: Text(
                    _languageService.translate('logout'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: _showLogoutConfirmation,
                ),
              ),
              
              const SizedBox(height: 16),
              const Divider(), // Keep only this divider
              const SizedBox(height: 16),
              
              // Reset Data Button
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)
                ),
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
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                    ),
                  ),
                  onTap: _showResetConfirmation,
                ),
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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

  // Show logout confirmation dialog
  Future<void> _showLogoutConfirmation() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(_languageService.translate('logoutConfirmation')),
          content: Text(_languageService.translate('areYouSureLogout')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_languageService.translate('cancel')),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _logout();
              },
              child: Text(
                _languageService.translate('logout'),
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
  
  // Logout user
  Future<void> _logout() async {
    try {
      final db = await _dbHelper.database;
      // Set all users as logged out
      await db.update('user', {'is_logged_in': 0, 'remember_me': 0});
      
      // Navigate to login screen
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      print('Error logging out: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_languageService.translate('logoutError')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
                  height: 20, width: 20,
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

  Future<void> _navigateToAppLockScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AppLockScreen(),
      ),
    );
  }
}

