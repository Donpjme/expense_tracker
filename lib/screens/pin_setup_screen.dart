import 'package:flutter/material.dart';
import 'package:expense_tracker/services/auth_service.dart';
import 'package:expense_tracker/screens/pin_auth_screen.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  _PinSetupScreenState createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final _authService = AuthService();
  bool _isPinEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    final isPinEnabled = await _authService.isPinAuthEnabled();
    final isPinSet = await _authService.isPinSet();

    setState(() {
      _isPinEnabled = isPinEnabled && isPinSet;
      _isLoading = false;
    });
  }

  Future<void> _togglePinAuth(bool value) async {
    if (value) {
      // Navigate to PIN setup
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PinAuthScreen(isSetup: true),
        ),
      );

      if (result == true) {
        await _loadSettings();
      }
    } else {
      // Verify PIN before disabling
      final result = await _showVerifyPinDialog();
      if (result == true) {
        await _authService.clearPin();
        await _authService.setPinAuthEnabled(false);
        await _loadSettings();
      }
    }
  }

  Future<bool?> _showVerifyPinDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Verify PIN'),
        content: Text(
            'Please enter your current PIN to disable PIN authentication.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PinAuthScreen(),
                ),
              );
              return result;
            },
            child: Text('Continue'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Security Settings'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                ListTile(
                  title: Text('PIN Authentication'),
                  subtitle: Text(
                    _isPinEnabled
                        ? 'PIN protection is enabled'
                        : 'Enable PIN to protect your data',
                  ),
                  trailing: Switch(
                    value: _isPinEnabled,
                    onChanged: _togglePinAuth,
                  ),
                ),
                if (_isPinEnabled)
                  ListTile(
                    title: Text('Change PIN'),
                    leading: Icon(Icons.lock_outline),
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PinAuthScreen(isSetup: true),
                        ),
                      );
                      if (result == true) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('PIN updated successfully')),
                        );
                      }
                    },
                  ),
              ],
            ),
    );
  }
}
