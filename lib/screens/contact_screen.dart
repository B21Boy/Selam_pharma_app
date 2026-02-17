import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher_string.dart';

class ContactScreen extends StatefulWidget {
  static const routeName = '/contact';
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController(text: 'Deksiyos Yismaw');
  final _emailCtrl = TextEditingController(text: 'deksiman721@gmail.com');
  final _phoneCtrl = TextEditingController(text: '0960625242');
  final _msgCtrl = TextEditingController();
  bool _loading = false;

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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message sent — we will contact you soon'),
            ),
          );
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to send — try again later')),
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
      appBar: AppBar(title: const Text('Contact Support')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name'),
                  textInputAction: TextInputAction.next,
                  validator: (v) => v!.trim().isEmpty ? 'Enter name' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      v != null && v.contains('@') ? null : 'Invalid email',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _msgCtrl,
                  decoration: const InputDecoration(labelText: 'Message'),
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
