import 'package:flutter/material.dart';
import '../l10n/app_en.dart';
import '../l10n/app_ru.dart';
import '../l10n/app_ky.dart';
import '../database/database_helper.dart';

class LanguageService {
  static final LanguageService _instance = LanguageService._internal();
  factory LanguageService() => _instance;
  
  LanguageService._internal();
  
  String _currentLanguage = 'en';
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  Map<String, Map<String, String>> translations = {
    'en': enTranslations,
    'ru': ruTranslations,
    'ky': kyTranslations,
  };
  
  Future<void> setLanguage(String languageCode) async {
    _currentLanguage = languageCode;
    await _dbHelper.setLanguage(languageCode);
  }
  
  Future<String> getCurrentLanguage() async {
    _currentLanguage = await _dbHelper.getLanguage();
    return _currentLanguage;
  }
  
  String translate(String key) {
    return translations[_currentLanguage]?[key] ?? translations['en']![key] ?? key;
  }

  Future<void> initLanguage() async {
    _currentLanguage = await _dbHelper.getLanguage();
  }
} 