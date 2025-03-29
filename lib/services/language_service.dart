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
    print('LanguageService: Setting language to $languageCode');
    _currentLanguage = languageCode;
    await _dbHelper.setLanguage(languageCode);
    print('LanguageService: Language saved to database');
  }
  
  Future<String> getCurrentLanguage() async {
    _currentLanguage = await _dbHelper.getLanguage();
    print('LanguageService: Current language retrieved: $_currentLanguage');
    return _currentLanguage;
  }
  
  String translate(String key) {
    final translation = translations[_currentLanguage]?[key] ?? translations['en']![key] ?? key;
    print('LanguageService: Translating key "$key" to "$translation" (current language: $_currentLanguage)');
    return translation;
  }

  Future<void> initLanguage() async {
    print('LanguageService: Initializing language');
    _currentLanguage = await _dbHelper.getLanguage();
    print('LanguageService: Initialized with language: $_currentLanguage');
  }
} 