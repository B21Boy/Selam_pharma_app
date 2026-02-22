import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher_string.dart';
import '../utils/ui_helpers.dart';

class ContactScreen extends StatefulWidget {
  static const routeName = '/contact';
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  bool _loading = false;

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showContactDialog();
    });
  }

  void _showContactDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Contact Information'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Phone No: +251960625242'),
              SizedBox(height: 8),
              Text('Email: deksiman721@gmail.com'),
              SizedBox(height: 8),
              Text('Telegram: @Dekxaaa'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final email = 'mailto:deksiman721@gmail.com';
                if (await canLaunchUrlString(email)) {
                  await launchUrlString(email);
                } else {
                  if (mounted) {
                    showAppSnackBar(
                      context,
                      'Unable to open email app',
                      error: true,
                    );
                  }
                }
              },
              child: const Text('Contact via Email'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final payload = {
      'name': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'message': _msgCtrl.text.trim(),
      'app': 'pharmacy_app',
      'platform': Theme.of(context).platform.toString(),
    };

    try {
      // Replace with your real endpoint if available
      final uri = Uri.parse('https://example.com/api/support');
      final res = await http
          .post(
            uri,
            body: jsonEncode(payload),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        if (mounted) {
          showAppSnackBar(context, 'Message sent — we will contact you soon');
          _msgCtrl.clear();
        }
      } else {
        throw Exception('server ${res.statusCode}');
      }
    } catch (_) {
      // fallback to mailto
      final subject = Uri.encodeComponent('App Support — ${_nameCtrl.text}');
      final body = Uri.encodeComponent(
        '${_msgCtrl.text}\n\nContact: ${_phoneCtrl.text}\nEmail: ${_emailCtrl.text}',
      );
      final mailto = 'mailto:deksiman721@gmail.com?subject=$subject&body=$body';
      if (await canLaunchUrlString(mailto)) {
        await launchUrlString(mailto);
      } else {
        if (mounted) {
          showAppSnackBar(
            context,
            'Unable to send — try again later',
            error: true,
          );
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Support'),
        titleSpacing: 20,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(12),
          child: SizedBox(height: 12),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: _fieldDecoration('Name'),
                  textInputAction: TextInputAction.next,
                  validator: (v) => v!.trim().isEmpty ? 'Enter name' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: _fieldDecoration('Email'),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      v != null && v.contains('@') ? null : 'Invalid email',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: _fieldDecoration('Phone'),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _msgCtrl,
                  decoration: _fieldDecoration('Message'),
                  maxLines: 6,
                  validator: (v) => v!.trim().isEmpty ? 'Enter message' : null,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _send,
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Send'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
