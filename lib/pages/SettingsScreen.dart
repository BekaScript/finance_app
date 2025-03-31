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
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _languageService = Provider.of<LanguageService>(context, listen: false);
  }

  Future<void> _loadSettings() async {
    final currency = await _dbHelper.getCurrency();
    final language = await _languageService.getCurrentLanguage();
    final isDarkMode = await _dbHelper.getDarkMode();
    if (mounted) {
      setState(() {
        _selectedCurrency = currency;
        _selectedLanguage = language;
        _isDarkMode = isDarkMode;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _languageService.translate('settings'),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // App Settings Section
                _SectionHeader(
                    title: _languageService.translate('appSettings')),
                const SizedBox(height: 8),
                _SettingsCard(
                  children: [
                    _SettingSwitchTile(
                      icon: Icons.dark_mode,
                      title: _languageService.translate('darkMode'),
                      value: _isDarkMode,
                      onChanged: (value) => _toggleTheme(),
                    ),
                    _SettingDropdownTile<String>(
                      icon: Icons.language,
                      title: _languageService.translate('selectLanguage'),
                      value: _selectedLanguage,
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
                      onChanged: (value) => _handleLanguageChange(value),
                    ),
                    _SettingDropdownTile<String>(
                      icon: Icons.currency_exchange,
                      title: _languageService.translate('selectCurrency'),
                      value: _selectedCurrency,
                      items: ['USD', 'EUR', 'INR', 'KGS'].map((currency) {
                        return DropdownMenuItem(
                          value: currency,
                          child: Text(_languageService.translate(currency)),
                        );
                      }).toList(),
                      onChanged: (value) => _handleCurrencyChange(value),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Data Management Section
                _SectionHeader(
                    title: _languageService.translate('dataManagement')),
                const SizedBox(height: 8),
                _SettingsCard(
                  children: [
                    _ActionTile(
                      icon: Icons.file_download,
                      iconColor: colorScheme.primary,
                      title: _languageService.translate('exportData'),
                      subtitle:
                          _languageService.translate('exportDataDescription'),
                      onTap: _showExportOptionsDialog,
                    ),
                    const Divider(height: 1),
                    _ActionTile(
                      icon: Icons.restore,
                      iconColor: Colors.orange,
                      title: _languageService.translate('resetData'),
                      subtitle:
                          _languageService.translate('resetDataDescription'),
                      onTap: _showResetConfirmation,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Account Section
                _SectionHeader(title: _languageService.translate('account')),
                const SizedBox(height: 8),
                _SettingsCard(
                  children: [
                    _ActionTile(
                      icon: Icons.login,
                      iconColor: colorScheme.primary,
                      title: _languageService.translate('loginRegister'),
                      onTap: () => Navigator.pushNamed(context, '/login'),
                    ),
                  ],
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleTheme() async {
    final newValue = !_isDarkMode;
    await _themeService.toggleTheme();
    if (mounted) {
      setState(() {
        _isDarkMode = newValue;
      });
    }
  }

  Future<void> _handleLanguageChange(String? newValue) async {
    if (newValue != null) {
      await _languageService.setLanguage(newValue);
      if (mounted) {
        setState(() {
          _selectedLanguage = newValue;
        });
        _showSnackBar(_languageService.translate('languageUpdated'));
      }
    }
  }

  Future<void> _handleCurrencyChange(String? newValue) async {
    if (newValue != null) {
      _showExchangeRateDialog(newValue);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Future<void> _showExchangeRateDialog(String currency) async {
    if (currency == _selectedCurrency) return;

    double currentRate = await _dbHelper.getExchangeRate(currency);
    final rateController =
        TextEditingController(text: currentRate.toStringAsFixed(2));

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _languageService.translate('setExchangeRate'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(_languageService.translate('cancel')),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        double? rate = double.tryParse(rateController.text);
                        if (rate != null && rate > 0) {
                          await _dbHelper.setExchangeRate(currency, rate);
                          await _dbHelper.setCurrency(currency);
                          if (mounted) {
                            setState(() {
                              _selectedCurrency = currency;
                            });
                            Navigator.pop(context);
                            _showSnackBar(_languageService
                                .translate('currencyRateUpdated'));
                          }
                        } else {
                          _showSnackBar(
                              _languageService.translate('invalidRate'));
                        }
                      },
                      child: Text(_languageService.translate('save')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showResetConfirmation() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resetData() async {
    try {
      _showLoadingSnackBar(_languageService.translate('resettingData'));
      final success = await _dbHelper.resetTransactionData();

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        if (success) {
          _showSnackBar(_languageService.translate('resetDataSuccess'));
        } else {
          _showSnackBar(_languageService.translate('resetDataError'));
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(_languageService.translate('resetDataError'));
      }
    }
  }

  void _showLoadingSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showExportOptionsDialog() async {
    await showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _languageService.translate('exportData'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(
                Icons.calendar_month,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(_languageService.translate('exportForCurrentMonth')),
              onTap: () {
                Navigator.pop(context);
                _exportCurrentMonth();
              },
            ),
            ListTile(
              leading: Icon(
                Icons.date_range,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(_languageService.translate('exportForCustomRange')),
              onTap: () {
                Navigator.pop(context);
                _showDateRangeDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportCurrentMonth() async {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    await _exportData(firstDayOfMonth, lastDayOfMonth);
  }

  Future<void> _showDateRangeDialog() async {
    final now = DateTime.now();
    DateTime startDate = DateTime(now.year, now.month, 1);
    DateTime endDate = now;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _languageService.translate('selectDateRange'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),
                  _DatePickerField(
                    label: _languageService.translate('selectStartDate'),
                    selectedDate: startDate,
                    onDateSelected: (date) {
                      setState(() {
                        startDate = date;
                        if (endDate.isBefore(startDate)) {
                          endDate = startDate;
                        }
                      });
                    },
                    firstDate: DateTime(2000),
                    lastDate: endDate,
                  ),
                  const SizedBox(height: 16),
                  _DatePickerField(
                    label: _languageService.translate('selectEndDate'),
                    selectedDate: endDate,
                    onDateSelected: (date) => setState(() => endDate = date),
                    firstDate: startDate,
                    lastDate: DateTime.now(),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _exportData(startDate, endDate);
                    },
                    child: Text(_languageService.translate('exportToCsv')),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _exportData(DateTime startDate, DateTime endDate) async {
    try {
      _showLoadingSnackBar(_languageService.translate('exporting'));
      final currency = await _dbHelper.getCurrency();
      final filePath = await _csvService.exportTransactionHistory(
        startDate,
        endDate,
        currency,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        if (filePath.isNotEmpty) {
          _showExportSuccessDialog(filePath);
        } else {
          _showSnackBar(_languageService.translate('exportError'));
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(_languageService.translate('exportError'));
      }
    }
  }

  Future<void> _showExportSuccessDialog(String filePath) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_languageService.translate('exportComplete')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_languageService.translate('exportSuccess')),
            const SizedBox(height: 8),
            Text(
              '${_languageService.translate('fileSaved')}\n$filePath',
              style: Theme.of(context).textTheme.bodySmall,
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
      ),
    );
  }

  Future<void> _shareFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await Share.shareXFiles([XFile(filePath)],
            text: _languageService.translate('transactionHistory'));
      } else {
        _showSnackBar(_languageService.translate('exportError'));
      }
    } catch (e) {
      _showSnackBar('Error sharing file: $e');
    }
  }
}

// Custom Widgets for consistent design

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).dividerColor,
          width: 1,
        ),
      ),
      child: Column(
        children: children
            .map((child) => [
                  child,
                  if (child != children.last)
                    const Divider(height: 1, indent: 16),
                ])
            .expand((element) => element)
            .toList(),
      ),
    );
  }
}

class _SettingSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingSwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: Theme.of(context).textTheme.bodyMedium),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: Theme.of(context).colorScheme.primary,
      ),
      minLeadingWidth: 24,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      onTap: () => onChanged(!value),
    );
  }
}

class _SettingDropdownTile<T> extends StatelessWidget {
  final IconData icon;
  final String title;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _SettingDropdownTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: Theme.of(context).textTheme.bodyMedium),
      trailing: DropdownButton<T>(
        value: value,
        underline: const SizedBox(),
        items: items,
        onChanged: onChanged,
      ),
      minLeadingWidth: 24,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title, style: Theme.of(context).textTheme.bodyMedium),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall,
            )
          : null,
      trailing: Icon(
        Icons.chevron_right,
        color: Theme.of(context).disabledColor,
      ),
      minLeadingWidth: 24,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      onTap: onTap,
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final DateTime firstDate;
  final DateTime lastDate;

  const _DatePickerField({
    required this.label,
    required this.selectedDate,
    required this.onDateSelected,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: selectedDate,
          firstDate: firstDate,
          lastDate: lastDate,
        );
        if (pickedDate != null) {
          onDateSelected(pickedDate);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(
          DateFormat('MMM dd, yyyy').format(selectedDate),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
