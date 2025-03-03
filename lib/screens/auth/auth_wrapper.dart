import 'package:flutter/material.dart';
import '../../services/local_auth_service.dart';
import 'pin_setup_screen.dart';
import 'pin_login_screen.dart';
import '../home_screen.dart';
import 'package:logger/logger.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final LocalAuthService _authService = LocalAuthService();
  final Logger _logger = Logger();
  bool _isLoading = true;
  bool _isAuthenticated = false;
  bool _showPinScreen = false;
  bool _needsPinSetup = false; // Flag for PIN setup

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    try {
      _logger.i("Checking authentication state");

      // First check if PIN is set
      final hasPIN = await _authService.hasPIN();
      _logger.i("Has PIN: $hasPIN");

      // If PIN is set, check authentication status
      bool isAuthenticated = false;
      if (hasPIN) {
        isAuthenticated = await _authService.isAuthenticated();
        _logger.i("Is authenticated: $isAuthenticated");
      }

      if (mounted) {
        setState(() {
          _isAuthenticated = isAuthenticated;
          _isLoading = false;
          _needsPinSetup = !hasPIN;

          // Show PIN screen immediately if user has never set up a PIN
          _showPinScreen = !hasPIN;
        });
      }
    } catch (e) {
      _logger.e("Error checking auth state", error: e);
      if (mounted) {
        setState(() {
          // Default to needing authentication in case of errors
          _isAuthenticated = false;
          _isLoading = false;
          _showPinScreen = true;
          _needsPinSetup = true;
        });
      }
    }
  }

  void _onAuthSuccess() {
    _logger.i("Authentication successful");
    setState(() {
      _isAuthenticated = true;
      _showPinScreen = false;
    });
  }

  void _onPinSetup() {
    _logger.i("PIN setup completed");
    setState(() {
      _isAuthenticated = true;
      _showPinScreen = false;
      _needsPinSetup = false;
    });
  }

  void _requestAuthentication() {
    _logger.i("Authentication requested");
    setState(() {
      _showPinScreen = true;
    });
  }

  void _onResetPin() async {
    _logger.i("PIN reset requested");

    try {
      // Actually reset the PIN in the service
      await _authService.resetPIN();

      // Update local state to reflect PIN has been reset
      setState(() {
        _isAuthenticated = false;
        _needsPinSetup = true; // This flag triggers the PIN setup screen
      });

      _logger.i("PIN reset successful, going to setup screen");
    } catch (e) {
      _logger.e("Error during PIN reset", error: e);
    }
  }

  void _onLogout() {
    _logger.i("User logged out");
    setState(() {
      _isAuthenticated = false;
      // Show PIN screen immediately after logout
      _showPinScreen = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // User needs to set up a PIN
    if (_needsPinSetup) {
      _logger.i("Showing PIN setup screen");
      return PinSetupScreen(onPinSetup: _onPinSetup);
    }

    // Show PIN login screen if needed
    if (_showPinScreen && !_isAuthenticated) {
      _logger.i("Showing PIN login screen");
      return PinLoginScreen(
        onLoginSuccess: _onAuthSuccess,
        onResetPin: _onResetPin, // Pass the reset handler
        onCancel: () {
          setState(() {
            _showPinScreen = false;
          });
        },
      );
    }

    // Show home screen with authentication check
    _logger.i("Showing home screen, authenticated: $_isAuthenticated");
    return HomeScreen(
      isAuthenticated: _isAuthenticated,
      onAuthenticationNeeded: _requestAuthentication,
      onLogout: _onLogout,
    );
  }
}
