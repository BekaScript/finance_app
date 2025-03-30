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
  
  static final Map<String, Map<String, String>> _translations = {
    'en': {
      // ... existing translations ...
      'wallets': 'Wallets',
      'dragToTransfer': 'Drag to transfer between wallets',
      'transferFunds': 'Transfer Funds',
      'from': 'From',
      'to': 'To',
      'amount': 'Amount',
      'transfer': 'Transfer',
      'enterAmount': 'Please enter an amount',
      'enterValidAmount': 'Please enter a valid amount greater than zero',
      'insufficientFunds': 'Insufficient funds in source wallet',
      'transferSuccess': 'Transfer completed successfully',
      'transferFailed': 'Transfer failed',
      'noWallets': 'No wallets found',
      // ... existing translations ...
    },
    'es': {
      // ... existing translations ...
      'wallets': 'Carteras',
      'dragToTransfer': 'Arrastra para transferir entre carteras',
      'transferFunds': 'Transferir Fondos',
      'from': 'De',
      'to': 'A',
      'amount': 'Cantidad',
      'transfer': 'Transferir',
      'enterAmount': 'Por favor, introduce una cantidad',
      'enterValidAmount': 'Por favor, introduce una cantidad válida mayor que cero',
      'insufficientFunds': 'Fondos insuficientes en la cartera de origen',
      'transferSuccess': 'Transferencia completada con éxito',
      'transferFailed': 'La transferencia falló',
      'noWallets': 'No se encontraron carteras',
      // ... existing translations ...
    },
    // ... other languages ...
  };
  
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