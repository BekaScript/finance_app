import 'package:flutter/material.dart';
import '../main.dart';
import '../database/database_helper.dart';

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

  // Function to handle login
  Future<bool> _login(String email, String password) async {
    try {
      final db = await _dbHelper.database;
      
      // First, reset all users' logged_in status
      await db.update('user', {'is_logged_in': 0});
      
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
          {'is_logged_in': 1},
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple, Colors.purpleAccent],
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
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // App Logo or Title
                        const Icon(
                          Icons.account_circle,
                          size: 80,
                          color: Colors.deepPurple,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isLogin ? "Welcome Back!" : "Create Account",
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Show name field only for registration
                        if (!_isLogin)
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              labelText: 'Name',
                              prefixIcon: const Icon(Icons.person),
                            ),
                            validator: (value) {
                              if (!_isLogin && (value == null || value.isEmpty)) {
                                return 'Please enter your name';
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
                            labelText: 'Email',
                            prefixIcon: const Icon(Icons.email),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
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
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock),
                          ),
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Login/Register Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (_formKey.currentState!.validate()) {
                                if (_isLogin) {
                                  // Handle Login
                                  final success = await _login(
                                    _emailController.text,
                                    _passwordController.text,
                                  );
                                  
                                  if (success) {
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(
                                        builder: (context) => const MainNavigationScreen(),
                                      ),
                                    );
                                  } else {
                                    _showError('Invalid email or password');
                                  }
                                } else {
                                  // Handle Registration
                                  final success = await _register(
                                    _nameController.text,
                                    _emailController.text,
                                    _passwordController.text,
                                  );
                                  
                                  if (success) {
                                    setState(() {
                                      _isLogin = true; // Switch to login view
                                    });
                                    _showError('Registration successful! Please login.');
                                    
                                    // Clear the form
                                    _nameController.clear();
                                    _emailController.clear();
                                    _passwordController.clear();
                                  } else {
                                    _showError('Email already exists or registration failed');
                                  }
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
                              _isLogin ? "Login" : "Register",
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
                                ? "Don't have an account? Register"
                                : "Already have an account? Login",
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
