import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../services/language_service.dart';
import '../database/database_helper.dart';
import 'package:intl/intl.dart';

class CsvService {
  final LanguageService _languageService = LanguageService();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Получение пути к директории документов
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  // Получение файла CSV
  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/transactions.csv');
  }

  // Добавление транзакции в CSV
  Future<void> addTransactionToCsv(Map<String, dynamic> transaction) async {
    try {
      File file = await _localFile;
      bool fileExists = await file.exists();

      // Создаем заголовки, если файл новый
      if (!fileExists) {
        final header = ['Type', 'Category', 'Amount', 'Date', 'Description'];

        String csv = const ListToCsvConverter().convert([header]);
        await file.writeAsString(csv);
      }

      // Подготовка данных транзакции
      final List<dynamic> transactionData = [
        transaction['type'],
        transaction['category'],
        transaction['amount'],
        transaction['date'],
        transaction['description'] ?? '',
      ];

      // Дописываем в файл новую строку
      String csv = '\n${const ListToCsvConverter().convert([transactionData])}';
      await file.writeAsString(csv, mode: FileMode.append);

      if (kDebugMode) {
        print('Транзакция успешно добавлена в CSV файл');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Ошибка при добавлении транзакции в CSV: $e');
      }
    }
  }

  // Чтение всех транзакций из CSV
  Future<List<List<dynamic>>> readTransactionsFromCsv() async {
    try {
      File file = await _localFile;
      bool fileExists = await file.exists();

      if (!fileExists) {
        return [];
      }

      String fileContent = await file.readAsString();
      List<List<dynamic>> transactions =
          const CsvToListConverter().convert(fileContent);

      return transactions;
    } catch (e) {
      if (kDebugMode) {
        print('Ошибка при чтении CSV: $e');
      }
      return [];
    }
  }

  // Export transaction history with totals and date range
  Future<String> exportTransactionHistory(
      DateTime startDate, DateTime endDate, String currency) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'transaction_history_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File('${directory.path}/$fileName');

      // Get transaction history data
      final history = await _dbHelper.getTransactionHistory(startDate, endDate);

      // Format dates for display
      final DateFormat dateFormatter = DateFormat('MMM dd, yyyy');
      final formattedStartDate = dateFormatter.format(startDate);
      final formattedEndDate = dateFormatter.format(endDate);

      // Prepare CSV data
      List<List<dynamic>> csvData = [];

      // Add report header
      csvData.add([
        'Transaction History Report',
      ]);
      csvData.add([
        'Date Range:',
        '$formattedStartDate to $formattedEndDate',
      ]);
      csvData.add([]);

      // Add summary section
      csvData.add([
        'Summary',
      ]);
      csvData.add([
        'Total Income:',
        '${history['totalIncome']} $currency',
      ]);
      csvData.add([
        'Total Expenses:',
        '${history['totalExpense']} $currency',
      ]);
      csvData.add([
        'Balance:',
        '${history['balance']} $currency',
      ]);
      csvData.add([]);

      // Add income by category
      csvData.add([
        'Income by Category',
      ]);

      final incomeByCategory =
          history['incomeByCategory'] as Map<String, double>;
      for (var entry in incomeByCategory.entries) {
        csvData.add([
          entry.key,
          '${entry.value} $currency',
        ]);
      }
      csvData.add([]);

      // Add expense by category
      csvData.add([
        'Expense by Category',
      ]);

      final expenseByCategory =
          history['expenseByCategory'] as Map<String, double>;
      for (var entry in expenseByCategory.entries) {
        csvData.add([
          entry.key,
          '${entry.value} $currency',
        ]);
      }
      csvData.add([]);

      // Add transactions section header
      csvData.add([
        'Transaction Details',
      ]);

      // Add column headers
      csvData.add([
        _languageService.translate('date'),
        _languageService.translate('type'),
        _languageService.translate('category'),
        _languageService.translate('amount'),
        _languageService.translate('description'),
      ]);

      // Add transaction data
      final transactions =
          history['transactions'] as List<Map<String, dynamic>>;
      for (var transaction in transactions) {
        csvData.add([
          transaction['date'],
          _languageService.translate(transaction['type']),
          transaction['category'],
          '${transaction['amount']} $currency',
          transaction['description'] ?? '',
        ]);
      }

      // Convert to CSV and save
      String csv = const ListToCsvConverter().convert(csvData);
      await file.writeAsString(csv);

      return file.path;
    } catch (e) {
      if (kDebugMode) {
        print('Error exporting transaction history: $e');
      }
      return '';
    }
  }

  // Экспорт всех транзакций в новый CSV файл
  Future<String> exportTransactions(
      List<Map<String, dynamic>> transactions) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'export_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File('${directory.path}/$fileName');

      // Создаем заголовки
      final header = [
        _languageService.translate('type'),
        _languageService.translate('category'),
        _languageService.translate('amount'),
        _languageService.translate('date'),
        _languageService.translate('description'),
      ];

      // Преобразуем транзакции в список строк CSV
      List<List<dynamic>> csvData = [header];

      for (var transaction in transactions) {
        csvData.add([
          transaction['type'],
          transaction['category'],
          transaction['amount'],
          transaction['date'],
          transaction['description'] ?? '',
        ]);
      }

      // Конвертируем и сохраняем
      String csv = const ListToCsvConverter().convert(csvData);
      await file.writeAsString(csv);

      return file.path;
    } catch (e) {
      if (kDebugMode) {
        print('Ошибка при экспорте транзакций: $e');
      }
      return '';
    }
  }

  // Удаление CSV файла при сбросе данных
  Future<void> resetCsvData() async {
    try {
      File file = await _localFile;
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Ошибка при сбросе CSV данных: $e');
      }
    }
  }

  // Получение переведенных заголовков для отображения
  List<String> getTranslatedHeaders() {
    return [
      _languageService.translate('type'),
      _languageService.translate('category'),
      _languageService.translate('amount'),
      _languageService.translate('date'),
      _languageService.translate('description'),
    ];
  }
}
