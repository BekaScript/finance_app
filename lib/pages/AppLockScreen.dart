import 'package:flutter/material.dart';
import 'package:personal_finance/services/language_service.dart';
import 'package:personal_finance/services/security_service.dart';
import 'package:personal_finance/pages/SetupPinScreen.dart';
import 'package:personal_finance/pages/LockScreen.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final SecurityService _securityService = SecurityService();
  final LanguageService _languageService = LanguageService();
  
  bool _isAppLockEnabled = false;
  bool _isBiometricEnabled = false;
  bool _isBiometricAvailable = false;
  int _lockTimeout = 60; // Default 1 minute (60 seconds)
  
  // List of available timeout options in seconds
  final List<int> _availableTimeouts = [5, 10, 30, 60, 300, 900, 1800, 3600];
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    final isAppLockEnabled = await _securityService.isAppLockEnabled();
    final isBiometricEnabled = await _securityService.isBiometricEnabled();
    final isBiometricAvailable = await _securityService.isBiometricAvailable();
    final timeout = await _securityService.getLockTimeout();
    
    // Ensure the timeout value is one of the available options
    int validTimeout = _ensureValidTimeout(timeout);
    
    if (mounted) {
      setState(() {
        _isAppLockEnabled = isAppLockEnabled;
        _isBiometricEnabled = isBiometricEnabled;
        _isBiometricAvailable = isBiometricAvailable;
        _lockTimeout = validTimeout;
      });
    }
  }
  
  // Ensures the timeout is one of the available options
  int _ensureValidTimeout(int seconds) {
    if (_availableTimeouts.contains(seconds)) {
      return seconds;
    }
    
    // Find the closest available timeout
    _availableTimeouts.sort();
    for (int availableTimeout in _availableTimeouts) {
      if (availableTimeout >= seconds) {
        return availableTimeout;
      }
    }
    
    // If no larger timeout found, return the largest available
    return _availableTimeouts.last;
  }
  
  Future<void> _toggleAppLock(bool value) async {
    // If enabling app lock, user must first set a PIN
    if (value && !_isAppLockEnabled) {
      final success = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => const SetupPinScreen(),
        ),
      );
      
      if (success != true) {
        return; // PIN setup was canceled
      }
    }
    
    await _securityService.setAppLock(value);
    
    // If disabling app lock, also disable biometrics
    if (!value) {
      await _securityService.setBiometricEnabled(false);
    }
    
    await _loadSettings();
  }
  
  Future<void> _toggleBiometric(bool value) async {
    await _securityService.setBiometricEnabled(value);
    await _loadSettings();
  }
  
  Future<void> _changePIN() async {
    final success = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const SetupPinScreen(isChangingPin: true),
      ),
    );
    
    if (success == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_languageService.translate('pinUpdated')),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
  
  Future<void> _setLockTimeout(int minutes) async {
    await _securityService.setLockTimeout(minutes);
    await _loadSettings();
  }

  Future<void> _lockNow() async {
    // Force app to lock immediately by navigating to LockScreen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LockScreen(),
        fullscreenDialog: true,
      ),
    );
    
    if (result == true) {
      // Authentication successful
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_languageService.translate('unlockSuccessful')),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _languageService.translate('appLock'),
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
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark 
              ? Colors.black.withAlpha(179)
              : Colors.white.withAlpha(179),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              // App Lock Toggle
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SwitchListTile.adaptive(
                  title: Text(
                    _languageService.translate('enableAppLock'),
                    style: const TextStyle(fontSize: 16),
                  ),
                  subtitle: Text(
                    _isAppLockEnabled 
                        ? _languageService.translate('enabled') 
                        : _languageService.translate('disabled'),
                  ),
                  value: _isAppLockEnabled,
                  onChanged: _toggleAppLock,
                  secondary: const Icon(Icons.lock, color: Colors.deepPurple),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Change PIN button (only shown when app lock is enabled)
              if (_isAppLockEnabled)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.pin, color: Colors.deepPurple),
                    title: Text(_languageService.translate('changePin')),
                    onTap: _changePIN,
                  ),
                ),
              
              if (_isAppLockEnabled)
                const SizedBox(height: 16),
              
              // Biometric Toggle (only shown when app lock is enabled and device supports biometrics)
              if (_isAppLockEnabled && _isBiometricAvailable)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile.adaptive(
                    title: Text(
                      _languageService.translate('useBiometric'),
                      style: const TextStyle(fontSize: 16),
                    ),
                    subtitle: Text(
                      _isBiometricEnabled 
                          ? _languageService.translate('enabled') 
                          : _languageService.translate('disabled'),
                    ),
                    value: _isBiometricEnabled,
                    onChanged: _toggleBiometric,
                    secondary: const Icon(Icons.fingerprint, color: Colors.deepPurple),
                  ),
                ),
              
              if (_isAppLockEnabled && _isBiometricAvailable)
                const SizedBox(height: 16),
              
              // Lock timeout selector (only shown when app lock is enabled)
              if (_isAppLockEnabled)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.timer, color: Colors.deepPurple),
                            const SizedBox(width: 16),
                            Text(
                              _languageService.translate('lockTimeout'),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _languageService.translate('lockTimeoutDescription'),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButton<int>(
                          value: _lockTimeout,
                          isExpanded: true,
                          onChanged: (int? value) {
                            if (value != null) {
                              _setLockTimeout(value);
                            }
                          },
                          items: [
                            DropdownMenuItem(
                              value: 5,
                              child: Text('5 ${_languageService.translate('seconds')}'),
                            ),
                            DropdownMenuItem(
                              value: 10,
                              child: Text('10 ${_languageService.translate('seconds')}'),
                            ),
                            DropdownMenuItem(
                              value: 30,
                              child: Text('30 ${_languageService.translate('seconds')}'),
                            ),
                            DropdownMenuItem(
                              value: 60,
                              child: Text('1 ${_languageService.translate('minute')}'),
                            ),
                            DropdownMenuItem(
                              value: 300,
                              child: Text('5 ${_languageService.translate('minutes')}'),
                            ),
                            DropdownMenuItem(
                              value: 900,
                              child: Text('15 ${_languageService.translate('minutes')}'),
                            ),
                            DropdownMenuItem(
                              value: 1800,
                              child: Text('30 ${_languageService.translate('minutes')}'),
                            ),
                            DropdownMenuItem(
                              value: 3600,
                              child: Text('1 ${_languageService.translate('hour')}'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              
              const SizedBox(height: 16),
              
              // Lock Now Button (only shown when app lock is enabled)
              if (_isAppLockEnabled)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: _lockNow,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.lock_outline,
                              color: Colors.deepPurple,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _languageService.translate('lockNow'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  _languageService.translate('lockNowDescription'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              
              const SizedBox(height: 16),
              
              // Info card about app lock
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            _languageService.translate('aboutAppLock'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _languageService.translate('appLockDescription'),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 