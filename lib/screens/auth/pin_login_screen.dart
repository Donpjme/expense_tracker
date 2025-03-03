import 'package:flutter/material.dart';
import '../../services/local_auth_service.dart';
import 'package:logger/logger.dart';

class PinLoginScreen extends StatefulWidget {
  final Function() onLoginSuccess;
  final Function() onResetPin; // Added this callback
  final Function()? onCancel; // Optional cancel callback

  const PinLoginScreen({
    required this.onLoginSuccess,
    required this.onResetPin, // New required parameter
    this.onCancel,
    super.key,
  });

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen>
    with SingleTickerProviderStateMixin {
  final LocalAuthService _authService = LocalAuthService();
  final TextEditingController _pinController = TextEditingController();
  final Logger _logger = Logger();
  late AnimationController _animationController;
  late Animation<double> _animation;

  String? _errorMessage;
  bool _isLoading = false;
  String? _userName;
  int _incorrectAttempts = 0;
  bool _isRetryLocked = false;
  bool _debugMode = false; // Debug mode toggle

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );

    _animationController.forward();
    _initialize();
  }

  Future<void> _initialize() async {
    // Set loading state
    setState(() {
      _isLoading = true;
    });

    try {
      // Clear any previous authentication session
      await _authService.setAuthenticationStatus(false);

      // Load user name for personalized welcome
      await _loadUserName();
    } catch (e) {
      _logger.e("Login initialization error", error: e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Login initialization failed. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadUserName() async {
    final name = await _authService.getUserName();
    if (mounted) {
      setState(() {
        _userName = name;
      });
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Special debug method to reset everything
  Future<void> _resetEverything() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.clearAllData();
      _logger.i("Everything has been reset");
      widget.onResetPin(); // Use the dedicated reset callback
    } catch (e) {
      _logger.e("Error resetting everything", error: e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Error resetting: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _verifyPin() async {
    if (_isRetryLocked) {
      setState(() {
        _errorMessage =
            'Too many failed attempts. Please wait before trying again.';
      });
      return;
    }

    if (_pinController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your PIN';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _logger.i("Verifying PIN");
      final isValid = await _authService.verifyPIN(_pinController.text);

      if (isValid) {
        _logger.i("PIN verified successfully");
        await _authService.setAuthenticationStatus(true);
        _incorrectAttempts = 0;
        widget.onLoginSuccess();
      } else {
        _incorrectAttempts++;
        _logger.w("Invalid PIN entered, attempt #$_incorrectAttempts");

        // Lock login after 5 incorrect attempts
        if (_incorrectAttempts >= 5) {
          _logger.w("Too many failed attempts, locking for 30 seconds");
          setState(() {
            _isRetryLocked = true;
            _errorMessage =
                'Too many failed attempts. Please wait 30 seconds before trying again.';
            _isLoading = false;
            _pinController.clear();
          });

          // Unlock after 30 seconds
          Future.delayed(const Duration(seconds: 30), () {
            if (mounted) {
              _logger.i("Unlocking PIN entry after timeout");
              setState(() {
                _isRetryLocked = false;
                _incorrectAttempts = 0;
                _errorMessage = 'You can try again now.';
              });
            }
          });
        } else {
          setState(() {
            _errorMessage =
                'Invalid PIN. Please try again. (${5 - _incorrectAttempts} attempts remaining)';
            _isLoading = false;
            _pinController.clear();
          });
        }
      }
    } catch (e) {
      _logger.e("PIN verification error", error: e);
      if (mounted) {
        setState(() {
          _errorMessage =
              'An error occurred during verification. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  // Handle PIN reset
  Future<void> _handlePinReset() async {
    try {
      // Show confirmation dialog
      final bool shouldReset = await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Reset PIN?'),
              content: const Text(
                  'If you reset your PIN, you\'ll need to set up a new one, '
                  'but your data will be preserved.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  child: const Text('Reset'),
                ),
              ],
            ),
          ) ??
          false;

      if (!shouldReset) return;

      setState(() {
        _isLoading = true;
      });

      // Actually reset the PIN
      await _authService.resetPIN();
      _logger.i("PIN reset successful");

      // Call the parent's onResetPin callback
      widget.onResetPin();
    } catch (e) {
      _logger.e("Error resetting PIN", error: e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Error resetting PIN: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leadingWidth: 70,
        actions: [
          // Debug mode toggle
          if (_debugMode)
            IconButton(
              icon: const Icon(Icons.delete_forever),
              onPressed: _resetEverything,
              tooltip: 'Reset Everything (Debug)',
            ),
        ],
        leading: widget.onCancel != null
            ? TextButton(
                onPressed: _isLoading ? null : widget.onCancel,
                child: const Text('Cancel'),
              )
            : null,
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: FadeTransition(
        opacity: _animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 0.1),
            end: Offset.zero,
          ).animate(_animation),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 20),

                          // Lock icon - tap 5 times to enable debug mode
                          GestureDetector(
                            onTap: () {
                              // Enable debug mode after 5 taps
                              if (!_debugMode) {
                                _incorrectAttempts++;
                                if (_incorrectAttempts >= 5) {
                                  setState(() {
                                    _debugMode = true;
                                    _incorrectAttempts = 0;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Debug mode enabled'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                }
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.lock_outline,
                                size: 50,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Welcome message
                          Text(
                            'Welcome back${_userName != null ? ", $_userName" : ""}!',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 8),

                          Text(
                            'Enter your PIN to continue',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 32),

                          // Error message
                          if (_errorMessage != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .errorContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onErrorContainer,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          if (_errorMessage != null) const SizedBox(height: 16),

                          // PIN field
                          TextField(
                            controller: _pinController,
                            decoration: InputDecoration(
                              labelText: 'Enter PIN',
                              prefixIcon: const Icon(Icons.lock),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            obscureText: !_debugMode, // Show PIN in debug mode
                            maxLength: 6,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _verifyPin(),
                            autofocus: true,
                            enabled: !_isLoading && !_isRetryLocked,
                          ),
                          const SizedBox(height: 24),

                          // Login button
                          ElevatedButton.icon(
                            onPressed: _isLoading || _isRetryLocked
                                ? null
                                : _verifyPin,
                            icon: const Icon(Icons.lock_open),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            label: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Unlock'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Forgot PIN option - at the bottom
                  TextButton(
                    onPressed:
                        _isLoading || _isRetryLocked ? null : _handlePinReset,
                    child: const Text('Forgot PIN?'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
