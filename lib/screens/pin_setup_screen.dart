import 'package:flutter/material.dart';
import 'package:expense_tracker/services/auth_service.dart';

class PinSetupScreen extends StatefulWidget {
  final bool isFirstTimeSetup;
  final VoidCallback? onSetupComplete;

  const PinSetupScreen(
      {this.isFirstTimeSetup = false, this.onSetupComplete, super.key});

  @override
  _PinSetupScreenState createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final _authService = AuthService();
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirmStep = false;
  String _errorMessage = '';
  bool _showError = false;

  void _onKeyPressed(String key) {
    setState(() {
      _showError = false;
      final currentPin = _isConfirmStep ? _confirmPin : _pin;

      if (currentPin.length < 4) {
        if (_isConfirmStep) {
          _confirmPin += key;
        } else {
          _pin += key;
        }
      }

      if (!_isConfirmStep && _pin.length == 4) {
        setState(() {
          _isConfirmStep = true;
        });
      }
    });
  }

  void _onBackspace() {
    setState(() {
      _showError = false;
      if (_isConfirmStep) {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        }
      } else {
        if (_pin.isNotEmpty) {
          _pin = _pin.substring(0, _pin.length - 1);
        }
      }
    });
  }

  Future<void> _onSubmit() async {
    // Create a local function to handle navigation to avoid context issues
    void navigateOrCallback() {
      if (widget.isFirstTimeSetup && widget.onSetupComplete != null) {
        widget.onSetupComplete!();
      } else {
        Navigator.of(context).pop(true);
      }
    }

    if (!_isConfirmStep) {
      setState(() {
        _isConfirmStep = true;
      });
      return;
    }

    if (_pin != _confirmPin) {
      setState(() {
        _showError = true;
        _errorMessage = 'PINs do not match. Please try again.';
        _confirmPin = '';
        _isConfirmStep = false;
      });
      return;
    }

    try {
      final success = await _authService.setPin(_pin);
      if (success) {
        await _authService.setPinAuthEnabled(true);

        if (mounted) {
          // Use the local navigation function
          navigateOrCallback();
        }
      } else {
        if (mounted) {
          setState(() {
            _showError = true;
            _errorMessage = 'Failed to set PIN. Please try again.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _showError = true;
          _errorMessage = 'An error occurred. Please try again.';
        });
      }
    }
  }

  Widget _buildPinDisplay() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        4,
        (index) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: index < (_isConfirmStep ? _confirmPin.length : _pin.length)
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.withOpacity(0.3),
          ),
        ),
      ),
    );
  }

  Widget _buildNumPad() {
    return Expanded(
      child: GridView.count(
        crossAxisCount: 3,
        childAspectRatio: 1.5,
        padding: const EdgeInsets.all(8),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          ...List.generate(9, (index) => _buildNumButton(index + 1)),
          _buildActionButton(Icons.backspace_outlined, _onBackspace),
          _buildNumButton(0),
          _buildActionButton(
            Icons.check_circle_outline,
            _onSubmit,
          ),
        ],
      ),
    );
  }

  Widget _buildNumButton(int number) {
    return InkWell(
      onTap: () => _onKeyPressed(number.toString()),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Center(
          child: Text(
            number.toString(),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            icon,
            size: 28,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Prevent back navigation during mandatory setup
      onWillPop: widget.isFirstTimeSetup ? () async => false : () async => true,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Icon(
                  Icons.lock_outline,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 30),
                Text(
                  widget.isFirstTimeSetup
                      ? (_isConfirmStep
                          ? 'Confirm your PIN'
                          : 'Create a 4-digit PIN')
                      : 'Set up PIN',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  widget.isFirstTimeSetup
                      ? 'This PIN will protect your expense data'
                      : 'Set a new PIN to secure your app',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                _buildPinDisplay(),
                if (_showError)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                      ),
                    ),
                  ),
                const SizedBox(height: 30),
                _buildNumPad(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
