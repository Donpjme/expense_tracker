import 'package:flutter/material.dart';
import '../../services/local_auth_service.dart';

class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen(
      {super.key}); // Using super parameter instead of key: key

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  final LocalAuthService _authService = LocalAuthService();
  final TextEditingController _currentPinController = TextEditingController();
  final TextEditingController _newPinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();

  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _changePin() async {
    // Validate inputs
    if (_currentPinController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your current PIN';
      });
      return;
    }

    if (_newPinController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a new PIN';
      });
      return;
    }

    if (_newPinController.text.length < 4) {
      setState(() {
        _errorMessage = 'PIN must be at least 4 digits';
      });
      return;
    }

    if (_newPinController.text != _confirmPinController.text) {
      setState(() {
        _errorMessage = 'New PINs do not match';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await _authService.changePIN(
        _currentPinController.text,
        _newPinController.text,
      );

      // Check if the widget is still mounted before using context
      if (!mounted) return;

      if (success) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN changed successfully')),
        );

        // Check again if mounted before navigating
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        setState(() {
          _errorMessage = 'Current PIN is incorrect. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      // Check if still mounted before updating state
      if (mounted) {
        setState(() {
          _errorMessage = 'An error occurred: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Change PIN'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Error message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red[900]),
                ),
              ),
            if (_errorMessage != null) const SizedBox(height: 16),

            // Current PIN field
            TextField(
              controller: _currentPinController,
              decoration: const InputDecoration(
                labelText: 'Current PIN',
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),

            // New PIN field
            TextField(
              controller: _newPinController,
              decoration: const InputDecoration(
                labelText: 'New PIN',
                prefixIcon: Icon(Icons.lock),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),

            // Confirm new PIN field
            TextField(
              controller: _confirmPinController,
              decoration: const InputDecoration(
                labelText: 'Confirm New PIN',
                prefixIcon: Icon(Icons.lock),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _changePin(),
            ),
            const SizedBox(height: 32),

            // Change PIN button
            ElevatedButton(
              onPressed: _isLoading ? null : _changePin,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Change PIN'),
            ),
          ],
        ),
      ),
    );
  }
}
