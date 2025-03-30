import 'package:flutter/material.dart';
import 'package:personal_finance/services/language_service.dart';
import 'package:personal_finance/services/security_service.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final LanguageService _languageService = LanguageService();
  final SecurityService _securityService = SecurityService();
  
  final List<String> _pin = [];
  String _errorText = '';
  bool _isLoading = false;
  bool _supportsBiometric = false;
  bool _isBiometricEnabled = false;
  
  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }
  
  Future<void> _checkBiometric() async {
    final isBiometricAvailable = await _securityService.isBiometricAvailable();
    final isBiometricEnabled = await _securityService.isBiometricEnabled();
    
    setState(() {
      _supportsBiometric = isBiometricAvailable;
      _isBiometricEnabled = isBiometricEnabled;
    });
    
    // If biometric is available and enabled, authenticate automatically
    if (_supportsBiometric && _isBiometricEnabled) {
      _authenticateWithBiometric();
    }
  }
  
  Future<void> _authenticateWithBiometric() async {
    setState(() {
      _isLoading = true;
    });
    
    final isAuthenticated = await _securityService.authenticateWithBiometrics();
    
    if (isAuthenticated) {
      _unlockApp();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _addDigit(String digit) {
    if (_pin.length < 4) {
      setState(() {
        _pin.add(digit);
        _errorText = ''; // Clear error text when user is typing
      });
      
      if (_pin.length == 4) {
        _verifyPin();
      }
    }
  }
  
  void _backspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin.removeLast();
      });
    }
  }
  
  Future<void> _verifyPin() async {
    setState(() {
      _isLoading = true;
    });
    
    final pin = _pin.join();
    final isValid = await _securityService.verifyAppPin(pin);
    
    if (isValid) {
      _unlockApp();
    } else {
      setState(() {
        _errorText = _languageService.translate('incorrectPin');
        _pin.clear();
        _isLoading = false;
      });
    }
  }
  
  void _unlockApp() {
    _securityService.recordLastAccess(); // Record successful unlock time
    Navigator.pop(context, true); // Return success
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back button
      child: Scaffold(
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
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // App Logo
                const Icon(
                  Icons.lock,
                  size: 80,
                  color: Colors.white,
                ),
                const SizedBox(height: 20),
                Text(
                  _languageService.translate('appLocked'),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  _languageService.translate('enterPinToUnlock'),
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 40),
                
                // PIN dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final bool isFilled = index < _pin.length;
                    
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFilled ? Colors.white : Colors.white.withOpacity(0.3),
                      ),
                    );
                  }),
                ),
                
                // Error text
                if (_errorText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Text(
                      _errorText,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                
                const SizedBox(height: 40),
                
                // Biometric button if available
                if (_supportsBiometric && _isBiometricEnabled)
                  GestureDetector(
                    onTap: _authenticateWithBiometric,
                    child: Column(
                      children: [
                        const Icon(
                          Icons.fingerprint,
                          size: 60,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _languageService.translate('useBiometric'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 20),
                
                // Loading indicator
                if (_isLoading)
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  )
                else
                  // Number pad
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 1.5,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: 12,
                        itemBuilder: (context, index) {
                          // Empty button for bottom left (index 9)
                          if (index == 9) {
                            return const SizedBox();
                          } 
                          // Numbers 1-9
                          else if (index < 9) {
                            final number = (index + 1).toString();
                            return _buildNumberButton(number);
                          } 
                          // 0 button
                          else if (index == 10) {
                            return _buildNumberButton('0');
                          } 
                          // Backspace button
                          else {
                            return _buildActionButton(
                              Icons.backspace,
                              _backspace,
                            );
                          }
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildNumberButton(String number) {
    return InkWell(
      onTap: () => _addDigit(number),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.2),
        ),
        alignment: Alignment.center,
        child: Text(
          number,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
  
  Widget _buildActionButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.2),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
} 