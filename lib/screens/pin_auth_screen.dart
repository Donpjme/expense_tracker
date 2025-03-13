import 'package:flutter/material.dart';
import 'package:expense_tracker/services/auth_service.dart';

class PinAuthScreen extends StatefulWidget {
  final bool isSetup;

  const PinAuthScreen({
    this.isSetup = false,
    super.key,
  });

  @override
  _PinAuthScreenState createState() => _PinAuthScreenState();
}

class _PinAuthScreenState extends State<PinAuthScreen> {
  final _authService = AuthService();
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirmStep = false;
  String _errorMessage = '';
  bool _showError = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: widget.isSetup
          ? AppBar(
              title: const Text('Set PIN'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
            )
          : null,
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
                widget.isSetup
                    ? _isConfirmStep
                        ? 'Confirm your PIN'
                        : 'Create a 4-digit PIN'
                    : 'Enter PIN to continue',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                widget.isSetup
                    ? 'This PIN will protect your expense data'
                    : 'Enter your PIN to access the app',
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
    );
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
            color: index < _getCurrentPin().length
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

  String _getCurrentPin() {
    return _isConfirmStep ? _confirmPin : _pin;
  }

  void _onKeyPressed(String key) {
    setState(() {
      _showError = false;
      final currentPin = _getCurrentPin();

      if (currentPin.length < 4) {
        if (_isConfirmStep) {
          _confirmPin += key;
        } else {
          _pin += key;
        }
      }

      if (_getCurrentPin().length == 4 && !widget.isSetup) {
        _onSubmit();
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

  void _onSubmit() async {
    // Store error handling function to avoid multiple context uses
    void showErrorState(String message) {
      if (mounted) {
        setState(() {
          _showError = true;
          _errorMessage = message;
        });
      }
    }

    if (_getCurrentPin().length < 4) {
      showErrorState('Please enter a 4-digit PIN');
      return;
    }

    if (widget.isSetup) {
      if (!_isConfirmStep) {
        // Move to PIN confirmation
        if (mounted) {
          setState(() {
            _isConfirmStep = true;
          });
        }
      } else {
        // Confirm and save PIN
        if (_pin == _confirmPin) {
          final success = await _authService.setPin(_pin);
          if (success) {
            if (mounted) {
              // Use a local function to handle navigation
              void navigateBack() {
                Navigator.of(context).pop(true);
              }

              navigateBack();
            }
          } else {
            showErrorState('Failed to save PIN. Please try again.');
          }
        } else {
          showErrorState('PINs don\'t match. Please try again.');
          if (mounted) {
            setState(() {
              _confirmPin = '';
            });
          }
        }
      }
    } else {
      // Verify PIN
      final isValid = await _authService.verifyPin(_pin);
      if (isValid) {
        if (mounted) {
          // Use a local function to handle navigation
          void navigateToHome() {
            Navigator.of(context).pushReplacementNamed('/home');
          }

          navigateToHome();
        }
      } else {
        showErrorState('Incorrect PIN. Please try again.');
        if (mounted) {
          setState(() {
            _pin = '';
          });
        }
      }
    }
  }
}
