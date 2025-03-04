import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:logger/logger.dart';

class LocalAuthService {
  // Keys for stored values
  static const String _pinKey = 'user_pin';
  static const String _authStatusKey = 'auth_status';
  static const String _userNameKey = 'user_name';
  static const String _initialSetupKey = 'initial_setup_completed';

  // Storage instances
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final Logger _logger = Logger();

  // Hash the PIN before storing for better security
  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Check if a PIN has been set up
  Future<bool> hasPIN() async {
    try {
      final hashedPin = await _secureStorage.read(key: _pinKey);
      _logger.i("PIN check: ${hashedPin != null}");
      return hashedPin != null && hashedPin.isNotEmpty;
    } catch (e) {
      _logger.e("Error checking PIN existence", error: e);
      return false;
    }
  }

  // Check if the user is authenticated
  Future<bool> isAuthenticated() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isAuthenticated = prefs.getBool(_authStatusKey) ?? false;
      _logger.i("Auth status check: $isAuthenticated");
      return isAuthenticated;
    } catch (e) {
      _logger.e("Error checking authentication status", error: e);
      return false;
    }
  }

  // Update authentication status
  Future<void> setAuthenticationStatus(bool status) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_authStatusKey, status);
      _logger.i("Auth status set to: $status");
    } catch (e) {
      _logger.e("Error setting auth status", error: e);
      throw e;
    }
  }

  // Check if initial setup is completed
  Future<bool> isInitialSetupCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isCompleted = prefs.getBool(_initialSetupKey) ?? false;
      _logger.i("Initial setup check: $isCompleted");
      return isCompleted;
    } catch (e) {
      _logger.e("Error checking initial setup status", error: e);
      return false;
    }
  }

  // Set initial setup completed
  Future<void> setInitialSetupCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_initialSetupKey, true);
      _logger.i("Initial setup marked as completed");
    } catch (e) {
      _logger.e("Error marking initial setup as completed", error: e);
      throw e;
    }
  }

  // Create a new PIN (during initial setup)
  Future<bool> createPIN(String pin, String userName) async {
    try {
      _logger.i("Creating new PIN and storing user name");
      // Store the hashed PIN
      final hashedPin = _hashPin(pin);
      await _secureStorage.write(key: _pinKey, value: hashedPin);

      // Store the user name
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userNameKey, userName);

      // Mark as authenticated
      await setAuthenticationStatus(true);

      // Mark initial setup as completed
      await setInitialSetupCompleted();

      return true;
    } catch (e) {
      _logger.e("Error creating PIN", error: e);
      return false;
    }
  }

  // Set up a new PIN (separate method for compatibility)
  Future<bool> setupPIN(String pin) async {
    try {
      _logger.i("Setting up PIN (compatibility method)");
      final hashedPin = _hashPin(pin);
      await _secureStorage.write(key: _pinKey, value: hashedPin);
      return true;
    } catch (e) {
      _logger.e("Error setting up PIN", error: e);
      return false;
    }
  }

  // Get the stored user name
  Future<String?> getUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userNameKey);
    } catch (e) {
      _logger.e("Error getting user name", error: e);
      return null;
    }
  }

  // Verify the entered PIN
  Future<bool> verifyPIN(String enteredPin) async {
    try {
      final storedHashedPin = await _secureStorage.read(key: _pinKey);

      // If no PIN is stored yet, any PIN is accepted for development purposes
      if (storedHashedPin == null || storedHashedPin.isEmpty) {
        _logger.w("No PIN found, accepting any PIN for development");
        return true;
      }

      final enteredHashedPin = _hashPin(enteredPin);
      final isValid = enteredHashedPin == storedHashedPin;
      _logger.i("PIN verification result: $isValid");
      return isValid;
    } catch (e) {
      _logger.e("Error verifying PIN", error: e);
      return false;
    }
  }

  // Change the PIN
  Future<bool> changePIN(String currentPin, String newPin) async {
    try {
      _logger.i("Attempting to change PIN");
      final isVerified = await verifyPIN(currentPin);
      if (!isVerified) {
        _logger.w("Current PIN verification failed, cannot change PIN");
        return false;
      }

      final newHashedPin = _hashPin(newPin);
      await _secureStorage.write(key: _pinKey, value: newHashedPin);
      _logger.i("PIN changed successfully");
      return true;
    } catch (e) {
      _logger.e("Error changing PIN", error: e);
      return false;
    }
  }

  // Reset the PIN (for forgot PIN functionality)
  Future<bool> resetPIN() async {
    try {
      _logger.i("Resetting PIN");
      await _secureStorage.delete(key: _pinKey);
      await setAuthenticationStatus(false);
      _logger.i("PIN reset successful");
      return true;
    } catch (e) {
      _logger.e("Error resetting PIN", error: e);
      return false;
    }
  }

  // Clear all authentication data (for debug/reset purposes)
  Future<void> clearAllData() async {
    try {
      _logger.i("Clearing all authentication data");
      await _secureStorage.deleteAll();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_authStatusKey);
      await prefs.remove(_userNameKey);
      await prefs.remove(_initialSetupKey);
      _logger.i("All authentication data cleared");
    } catch (e) {
      _logger.e("Error clearing authentication data", error: e);
      throw e;
    }
  }

  // Log out user
  Future<void> logOut() async {
    try {
      _logger.i("Logging out user");
      await setAuthenticationStatus(false);
    } catch (e) {
      _logger.e("Error logging out", error: e);
      throw e;
    }
  }
}
