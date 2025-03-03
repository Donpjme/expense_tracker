import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:logger/logger.dart';
import '../services/local_auth_service.dart';

class BiometricAuthService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final LocalAuthService _authService;
  final Logger _logger = Logger();

  BiometricAuthService(this._authService);

  Future<bool> isBiometricAvailable() async {
    try {
      // Not available on web platform
      if (kIsWeb) return false;

      // Check if biometric authentication is available
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      _logger.i(
          'Biometrics available: $canCheckBiometrics, Device supported: $isDeviceSupported');

      return canCheckBiometrics && isDeviceSupported;
    } catch (e) {
      _logger.e('Error checking biometric availability: $e');
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      if (kIsWeb) return [];

      final biometrics = await _localAuth.getAvailableBiometrics();
      _logger.i('Available biometrics: $biometrics');
      return biometrics;
    } catch (e) {
      _logger.e('Error getting available biometrics: $e');
      return [];
    }
  }

  Future<bool> authenticate() async {
    try {
      if (kIsWeb) return false;

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access your Expense Tracker',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      _logger.i('Biometric authentication result: $authenticated');

      if (authenticated) {
        await _authService.setAuthenticationStatus(true);
      }

      return authenticated;
    } catch (e) {
      _logger.e('Error authenticating with biometrics: $e', error: e);
      return false;
    }
  }
}
