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
    print('ThemeService: Initializing theme');
    final isDarkMode = await _dbHelper.getDarkMode();
    print('ThemeService: Current dark mode setting: $isDarkMode');
    _themeController.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    print('ThemeService: Theme mode set to: ${_themeController.value}');
  }
  
  Future<void> toggleTheme() async {
    print('ThemeService: Toggling theme');
    final isDarkMode = _themeController.value == ThemeMode.dark;
    print('ThemeService: Current theme mode: ${_themeController.value}');
    
    // Update database first
    await _dbHelper.setDarkMode(!isDarkMode);
    print('ThemeService: Dark mode saved to database: ${!isDarkMode}');
    
    // Then update the theme controller
    _themeController.value = isDarkMode ? ThemeMode.light : ThemeMode.dark;
    print('ThemeService: New theme mode set to: ${_themeController.value}');
  }
} 