import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;

  SecurityService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();
  
  // Key names for shared preferences
  final String _isAppLockEnabledKey = 'is_app_lock_enabled';
  final String _appPinKey = 'app_pin';
  final String _isBiometricEnabledKey = 'is_biometric_enabled';
  final String _lockTimeoutKey = 'lock_timeout'; // in seconds

  // Initialize security settings
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Set default values if none exist
    if (!prefs.containsKey(_isAppLockEnabledKey)) {
      await prefs.setBool(_isAppLockEnabledKey, false);
    }
    
    if (!prefs.containsKey(_isBiometricEnabledKey)) {
      await prefs.setBool(_isBiometricEnabledKey, false);
    }
    
    if (!prefs.containsKey(_lockTimeoutKey)) {
      await prefs.setInt(_lockTimeoutKey, 60); // Default 1 minute (60 seconds)
    }
  }

  // Check if app lock is enabled
  Future<bool> isAppLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isAppLockEnabledKey) ?? false;
  }

  // Enable or disable app lock
  Future<void> setAppLock(bool isEnabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isAppLockEnabledKey, isEnabled);
  }

  // Set app PIN
  Future<void> setAppPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_appPinKey, pin);
  }

  // Verify app PIN
  Future<bool> verifyAppPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedPin = prefs.getString(_appPinKey) ?? '';
    return storedPin == pin;
  }

  // Check if biometric is enabled
  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isBiometricEnabledKey) ?? false;
  }

  // Enable or disable biometric authentication
  Future<void> setBiometricEnabled(bool isEnabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isBiometricEnabledKey, isEnabled);
  }

  // Check if biometric is available on the device
  Future<bool> isBiometricAvailable() async {
    try {
      final canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();
      return canAuthenticate;
    } on PlatformException catch (_) {
      return false;
    }
  }

  // Get available biometrics
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException catch (_) {
      return [];
    }
  }

  // Authenticate with biometrics
  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to access the app',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } on PlatformException catch (_) {
      return false;
    }
  }

  // Set lock timeout in seconds
  Future<void> setLockTimeout(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lockTimeoutKey, seconds);
  }

  // Get lock timeout in seconds
  Future<int> getLockTimeout() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lockTimeoutKey) ?? 60; // Default 1 minute (60 seconds)
  }

  // Store the last time the app was accessed
  Future<void> recordLastAccess() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt('last_access_time', now);
  }

  // Check if app should be locked based on timeout
  Future<bool> shouldLockApp() async {
    if (!await isAppLockEnabled()) {
      return false;
    }
    
    final prefs = await SharedPreferences.getInstance();
    final lastAccessTime = prefs.getInt('last_access_time') ?? 0;
    final timeoutSeconds = await getLockTimeout();
    
    final now = DateTime.now().millisecondsSinceEpoch;
    final timeElapsedMs = now - lastAccessTime;
    final timeElapsedSeconds = timeElapsedMs / 1000; // elapsed time in seconds
    
    print('Time elapsed: $timeElapsedSeconds seconds, Timeout: $timeoutSeconds seconds'); // Debug
    return timeElapsedSeconds >= timeoutSeconds;
  }
} 