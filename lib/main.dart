import 'package:flutter/material.dart';
import 'package:personal_finance/database/database_helper.dart';
import 'package:personal_finance/pages/HomeScreen.dart';
import 'package:personal_finance/pages/TransactionHistoryScreen.dart';
import 'package:personal_finance/pages/ReportsScreen.dart';
import 'package:personal_finance/pages/SettingsScreen.dart';
import 'package:personal_finance/pages/LogingRegister.dart';
import 'package:personal_finance/services/language_service.dart';
import 'package:personal_finance/services/theme_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dbHelper = DatabaseHelper();
  final languageService = LanguageService();
  final themeService = ThemeService();
  
  try {
    await dbHelper.database;
    
    // Initialize default data in specific order
    await dbHelper.insertDefaultCategories(); // Add default categories if none exist
    await dbHelper.insertDefaultWallets(); // Add default wallets if none exist
    
    // Initialize services
    await languageService.initLanguage();
    await themeService.initTheme();
  } catch (e) {
    print("Error initializing: $e");
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final languageService = LanguageService();
    final themeService = ThemeService();

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeService.themeController,
      builder: (context, themeMode, child) {
        return MaterialApp(
          title: languageService.translate('personalFinance'),
          theme: _buildLightTheme(),
          darkTheme: _buildDarkTheme(),
          themeMode: themeMode,
          debugShowCheckedModeBanner: false,
          home: const MainNavigationScreen(),
          routes: {
            '/login': (context) => const Loginregister(),
            '/home': (context) => const MainNavigationScreen(),
          },
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en', 'US'),
            Locale('ru', 'RU'),
            Locale('ky', 'KG'),
          ],
        );
      },
    );
  }
  
  ThemeData _buildLightTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.white,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.black),
        bodyMedium: TextStyle(color: Colors.black),
        titleLarge: TextStyle(color: Colors.black),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.grey[900],
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white),
        titleLarge: TextStyle(color: Colors.white),
      ),
      cardColor: Colors.grey[800],
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: Colors.grey[900],
        scrimColor: Colors.black54,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.grey[900],
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey[400],
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: Colors.grey[800],
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.deepPurple),
        ),
        labelStyle: const TextStyle(color: Colors.white),
        hintStyle: TextStyle(color: Colors.grey[400]),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.deepPurple;
          }
          return Colors.grey[400];
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.deepPurple.withOpacity(0.5);
          }
          return Colors.grey[600];
        }),
      ),
      dividerColor: Colors.grey[700],
      dividerTheme: DividerThemeData(
        color: Colors.grey[700],
        thickness: 1,
      ),
      listTileTheme: const ListTileThemeData(
        textColor: Colors.white,
        iconColor: Colors.white,
      ),
      cardTheme: CardTheme(
        color: Colors.grey[800],
        elevation: 2,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: Colors.grey[800],
        titleTextStyle: const TextStyle(color: Colors.white),
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Colors.grey[800],
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  _MainNavigationScreenState createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(key: ValueKey('HomeScreen')),
    const TransactionHistoryScreen(key: ValueKey('TransactionHistoryScreen')),
    const ReportsScreen(key: ValueKey('ReportsScreen')),
    const SettingsScreen(key: ValueKey('SettingsScreen')),
  ];

  final LanguageService _languageService = LanguageService();
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Add lifecycle observer
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Remove lifecycle observer
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('App lifecycle state changed to: $state');
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _screens[_selectedIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[900] : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onItemTapped,
            backgroundColor: Colors.transparent,
            elevation: 0,
            indicatorColor: Colors.transparent,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              NavigationDestination(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _selectedIndex == 0
                        ? Colors.deepPurple.withOpacity(0.2)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.home_outlined,
                    color: _selectedIndex == 0 
                        ? Colors.deepPurple 
                        : (isDarkMode ? Colors.grey[400] : Colors.grey),
                  ),
                ),
                selectedIcon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.home,
                    color: Colors.deepPurple,
                  ),
                ),
                label: _languageService.translate('home'),
              ),
              NavigationDestination(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _selectedIndex == 1
                        ? Colors.deepPurple.withOpacity(0.2)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.history_outlined,
                    color: _selectedIndex == 1 
                        ? Colors.deepPurple 
                        : (isDarkMode ? Colors.grey[400] : Colors.grey),
                  ),
                ),
                selectedIcon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.history,
                    color: Colors.deepPurple,
                  ),
                ),
                label: _languageService.translate('history'),
              ),
              NavigationDestination(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _selectedIndex == 2
                        ? Colors.deepPurple.withOpacity(0.2)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.bar_chart_outlined,
                    color: _selectedIndex == 2 
                        ? Colors.deepPurple 
                        : (isDarkMode ? Colors.grey[400] : Colors.grey),
                  ),
                ),
                selectedIcon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bar_chart,
                    color: Colors.deepPurple,
                  ),
                ),
                label: _languageService.translate('reports'),
              ),
              NavigationDestination(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _selectedIndex == 3
                        ? Colors.deepPurple.withOpacity(0.2)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.settings_outlined,
                    color: _selectedIndex == 3 
                        ? Colors.deepPurple 
                        : (isDarkMode ? Colors.grey[400] : Colors.grey),
                  ),
                ),
                selectedIcon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.settings,
                    color: Colors.deepPurple,
                  ),
                ),
                label: _languageService.translate('settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Screen to check if user is logged in
class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _checkLoggedInUser();
  }

  Future<void> _checkLoggedInUser() async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> users = await db.query(
        'user',
        where: 'is_logged_in = ? OR remember_me = ?',
        whereArgs: [1, 1],
        limit: 1,
      );

      // Delayed navigation to ensure the widget is mounted
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        if (users.isNotEmpty) {
          // User is logged in or has remember me set
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
          );
        } else {
          // No logged in user
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const Loginregister()),
          );
        }
      }
    } catch (e) {
      print('Error checking logged in user: $e');
      // On error, default to login screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const Loginregister()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Colors.deepPurple,
            ),
            const SizedBox(height: 24),
            Text(
              LanguageService().translate('loading'),
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
