import 'package:flutter/material.dart';
import '../database/database_helper.dart';

class ThemeService {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  
  ThemeService._internal();
  
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _themeController = ValueNotifier<ThemeMode>(ThemeMode.light);
  
  ValueNotifier<ThemeMode> get themeController => _themeController;
  
  Future<void> initTheme() async {
    final isDarkMode = await _dbHelper.getDarkMode();
    _themeController.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;
  }
  
  Future<void> toggleTheme() async {
    final isDarkMode = _themeController.value == ThemeMode.dark;
    
    // Update database first
    await _dbHelper.setDarkMode(!isDarkMode);
    
    // Then update the theme controller
    _themeController.value = isDarkMode ? ThemeMode.light : ThemeMode.dark;
  }
} 