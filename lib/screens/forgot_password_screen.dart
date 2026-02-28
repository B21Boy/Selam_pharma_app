import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/ui_helpers.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final AuthService _auth = AuthService();
  bool _loading = false;

  void _showMsg(Object e) {
    final msg = e is String ? e : _auth.friendlyError(e);
    showAppSnackBar(context, msg, error: e is! String);
  }

  Future<void> _submit() async {
    if (mounted) setState(() => _loading = true);
    try {
      await _auth.sendPasswordReset(_emailCtrl.text.trim());
      if (!mounted) return;
      _showMsg('Password reset email sent');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) _showMsg(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Reset password')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              controller: _emailCtrl,
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(fontSize: 12),
                hintStyle: TextStyle(fontSize: 12),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
              ),
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _loading
                    ? SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text('Send reset email', style: TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
