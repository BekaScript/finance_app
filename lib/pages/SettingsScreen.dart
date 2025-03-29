import 'package:flutter/material.dart';
import 'package:personal_finance/database/database_helper.dart';
import 'package:personal_finance/services/language_service.dart';
import 'package:personal_finance/services/theme_service.dart';


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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const Divider(),

              // Currency Selection
              ListTile(
                leading: const Icon(Icons.attach_money, color: Colors.deepPurple),
                title: Text(_languageService.translate('selectCurrency')),
                subtitle: DropdownButtonFormField<String>(
                  value: _selectedCurrency,
                  onChanged: _selectCurrency,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  items: [
                    DropdownMenuItem(value: 'USD', child: Text('USD - ${_languageService.translate('USD')}')),
                    DropdownMenuItem(value: 'EUR', child: Text('EUR - ${_languageService.translate('EUR')}')),
                    DropdownMenuItem(value: 'INR', child: Text('INR - ${_languageService.translate('INR')}')),
                    DropdownMenuItem(value: 'KGS', child: Text('KGS - ${_languageService.translate('KGS')}')),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Divider(),

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
            ],
          ),
        ),
      ),
    );
  }
}

