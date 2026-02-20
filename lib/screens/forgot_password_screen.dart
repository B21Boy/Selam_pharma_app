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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _emailCtrl,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: Text('Send reset email'),
            ),
          ],
        ),
      ),
    );
  }
}
