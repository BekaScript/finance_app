import 'package:flutter/material.dart';
import 'package:personal_finance/database/database_helper.dart';
import 'package:personal_finance/services/language_service.dart';

import '../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final LanguageService _languageService = LanguageService();
  bool _isDarkMode = false;
  String _selectedCurrency = 'USD';
  bool _isFingerprintEnabled = false;
  String _selectedLanguage = 'en';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final currency = await _dbHelper.getCurrency();
    final language = await _languageService.getCurrentLanguage();
    if (mounted) {
      setState(() {
        _selectedCurrency = currency;
        _selectedLanguage = language;
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

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  void _toggleFingerprint(bool value) {
    setState(() {
      _isFingerprintEnabled = value;
    });
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

            // Fingerprint Authentication
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: SwitchListTile.adaptive(
                title: Text(_languageService.translate('enableFingerprint'), style: const TextStyle(fontSize: 16)),
                subtitle: Text(_isFingerprintEnabled ? _languageService.translate('enabled') : _languageService.translate('disabled')),
                value: _isFingerprintEnabled,
                onChanged: _toggleFingerprint,
                secondary:
                    const Icon(Icons.fingerprint, color: Colors.deepPurple),
              ),
            ),

            const SizedBox(height: 20),

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
    );
  }
}

