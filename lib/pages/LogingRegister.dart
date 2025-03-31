import 'package:flutter/material.dart';
import '../main.dart';
import '../database/database_helper.dart';
import '../services/language_service.dart';

class Loginregister extends StatefulWidget {
  const Loginregister({super.key});

  @override
  State<Loginregister> createState() => _LoginregisterState();
}

class _LoginregisterState extends State<Loginregister> {
  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final LanguageService _languageService = LanguageService();
  bool _rememberMe = false;
  String _errorMessage = '';
  bool _isLoading = false;

  // Function to handle login
  Future<bool> _login(String email, String password) async {
    try {
      final db = await _dbHelper.database;
      
      // First, reset all users' logged_in status if not using remember me
      if (!_rememberMe) {
        await db.update('user', {'is_logged_in': 0});
      }
      
      // Check user credentials
      final List<Map<String, dynamic>> users = await db.query(
        'user',
        where: 'email = ? AND password = ?',
        whereArgs: [email, password],
      );
      
      if (users.isNotEmpty) {
        // Set this user as logged in
        await db.update(
          'user',
          {'is_logged_in': 1, 'remember_me': _rememberMe ? 1 : 0},
          where: 'email = ?',
          whereArgs: [email]
        );
        return true;
      }
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  // Function to handle registration
  Future<bool> _register(String name, String email, String password) async {
    try {
      final db = await _dbHelper.database;
      
      // Check if email already exists
      final List<Map<String, dynamic>> existingUsers = await db.query(
        'user',
        where: 'email = ?',
        whereArgs: [email],
      );
      
      if (existingUsers.isNotEmpty) {
        return false; // Email already exists
      }

      // Insert new user
      await db.insert('user', {
        'name': name,
        'email': email,
        'password': password,
      });
      
      return true;
    } catch (e) {
      print('Error registering user: $e');
      return false;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _handleRegistration() async {
    final String name = _nameController.text.trim();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;
    
    // Basic validation
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = _languageService.translate('allFieldsRequired');
      });
      return;
    }
    
    // Email validation
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      setState(() {
        _errorMessage = _languageService.translate('invalidEmail');
      });
      return;
    }
    
    // Password strength validation
    if (password.length < 6) {
      setState(() {
        _errorMessage = _languageService.translate('passwordTooShort');
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // Register the user with DatabaseHelper
      final userData = {
        'name': name,
        'email': email,
        'password': password,
        'is_logged_in': 1, // Login after registration
        'remember_me': 0,
      };
      
      final result = await _dbHelper.registerUser(userData);
      
      setState(() {
        _isLoading = false;
      });
      
      if (result == -1) {
        // User already exists
        setState(() {
          _errorMessage = _languageService.translate('emailAlreadyExists');
        });
      } else if (result > 0) {
        // Registration successful, navigate to home
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        // Unknown error
        setState(() {
          _errorMessage = _languageService.translate('registrationFailed');
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  Future<void> _handleLogin() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;
    
    // Basic validation
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = _languageService.translate('emailAndPasswordRequired');
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // Login with DatabaseHelper
      final user = await _dbHelper.loginUser(
        email,
        password,
        _rememberMe,
      );
      
      setState(() {
        _isLoading = false;
      });
      
      if (user != null) {
        // Login successful, navigate to home
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        // Invalid credentials
        setState(() {
          _errorMessage = _languageService.translate('invalidCredentials');
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isLogin
              ? _languageService.translate('login')
              : _languageService.translate('register'),
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
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1A237E),
              const Color(0xFF64B5F6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.black 
                    : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo or app name
                        const SizedBox(height: 24),
                        Icon(
                          _isLogin ? Icons.lock_open : Icons.person_add,
                          size: 80,
                          color: Colors.deepPurple,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _isLogin
                              ? _languageService.translate('welcomeBack')
                              : _languageService.translate('createAccount'),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        
                        // Error message
                        if (_errorMessage.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(10),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red),
                            ),
                            child: Text(
                              _errorMessage,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        
                        // Show name field only for registration
                        if (!_isLogin)
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              labelText: _languageService.translate('name'),
                              prefixIcon: const Icon(Icons.person),
                            ),
                            validator: (value) {
                              if (!_isLogin && (value == null || value.isEmpty)) {
                                return _languageService.translate('pleaseEnterName');
                              }
                              return null;
                            },
                          ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            labelText: _languageService.translate('email'),
                            prefixIcon: const Icon(Icons.email),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return _languageService.translate('pleaseEnterEmail');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            labelText: _languageService.translate('password'),
                            prefixIcon: const Icon(Icons.lock),
                          ),
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return _languageService.translate('pleaseEnterPassword');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Remember Me Checkbox (only shown on login screen)
                        if (_isLogin)
                          Row(
                            children: [
                              Checkbox(
                                value: _rememberMe,
                                onChanged: (value) {
                                  setState(() {
                                    _rememberMe = value ?? false;
                                  });
                                },
                                activeColor: Colors.deepPurple,
                              ),
                              Text(
                                _languageService.translate('rememberMe'),
                                style: TextStyle(
                                  color: Theme.of(context).textTheme.bodyMedium?.color,
                                ),
                              ),
                            ],
                          ),
                          
                        // Login/Register Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (_formKey.currentState!.validate()) {
                                if (_isLogin) {
                                  // Handle Login
                                  await _handleLogin();
                                } else {
                                  // Handle Registration
                                  await _handleRegistration();
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: const BorderSide(
                                    color: Colors.deepPurple, width: 2),
                              ),
                              backgroundColor: Colors.deepPurple,
                            ),
                            child: Text(
                              _isLogin ? _languageService.translate('login') : _languageService.translate('register'),
                              style: const TextStyle(
                                  fontSize: 18,
                                  color: Color.fromARGB(255, 255, 255, 255),
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Toggle between Login and Register
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isLogin = !_isLogin;
                            });
                          },
                          child: Text(
                            _isLogin
                                ? _languageService.translate('dontHaveAccount')
                                : _languageService.translate('alreadyHaveAccount'),
                            style: const TextStyle(color: Colors.deepPurple),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
