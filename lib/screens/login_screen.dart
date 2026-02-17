import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final AuthService _auth = AuthService();
  bool _loading = false;
  String? _emailError;
  String? _passwordError;

  void _showError(Object e) {
    final msg = _auth.friendlyError(e);
    final debugSuffix = kDebugMode
        ? ' (${e.runtimeType}: ${e.toString()})'
        : '';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$msg$debugSuffix')));
    debugPrint('LoginScreen._showError: $e');
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (mounted) {
      setState(() {
        _loading = true;
        _emailError = null;
        _passwordError = null;
      });
    }
    debugPrint(
      'LoginScreen._submit: attempt sign-in for ${_emailCtrl.text.trim()}',
    );
    try {
      await _auth.signInWithEmail(_emailCtrl.text.trim(), _passCtrl.text);
      debugPrint('LoginScreen._submit: signInWithEmail returned');
      User? u = FirebaseAuth.instance.currentUser;
      debugPrint('Signed in user immediate check: uid=${u?.uid}');

      if (u == null) {
        // Sometimes the Firebase SDK hasn't propagated the currentUser immediately.
        // Wait a short while and poll for the auth state before failing.
        debugPrint(
          'currentUser was null immediately after sign-in, waiting for propagation...',
        );
        bool found = false;
        for (var i = 0; i < 6; i++) {
          await Future.delayed(const Duration(milliseconds: 500));
          u = FirebaseAuth.instance.currentUser;
          debugPrint('poll $i -> uid=${u?.uid}');
          if (u != null) {
            found = true;
            break;
          }
        }

        if (!found) {
          debugPrint(
            'Sign-in returned but currentUser remained null after polling',
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Signed in but no user object found.'),
              ),
            );
          }
        }
      }

      if (u != null) {
        debugPrint(
          'Sign-in successful, navigating to Home: ${u.email} uid=${u.uid}',
        );
        if (!mounted) return;
        try {
          // Ensure Firestore profile exists and load it (basic check).
          try {
            final uid = u.uid;
            final doc = await FirestoreService.getDocument('users/$uid');
            if (doc == null || !doc.exists) {
              // Create a default profile if missing
              await FirestoreService.set('users/$uid', {
                'email': u.email,
                'role': 'user',
                'displayName': u.displayName ?? '',
                'createdAt': DateTime.now().toUtc().toIso8601String(),
              });
              debugPrint('Created missing Firestore profile for $uid');
            } else {
              debugPrint('Loaded Firestore profile for $uid');
            }
          } catch (profileErr) {
            debugPrint('Error loading/creating Firestore profile: $profileErr');
          }

          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Signed in as ${u.email}')));
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => HomeScreen()),
            (route) => false,
          );
        } catch (navErr) {
          debugPrint('Navigation error after sign-in: $navErr');
        }
      }
    } catch (e) {
      final errText = e.toString();
      final isPigeonTypeError =
          errText.contains('Pigeon') || errText.contains('is not a subtype of');
      debugPrint(
        'Sign-in exception: ${isPigeonTypeError ? 'platform/plugin type error' : e}',
      );

      // If the platform layer threw a pigeon/type error but the sign-in actually
      // succeeded on the backend, FirebaseAuth.instance.currentUser may be set.
      final uCheck = FirebaseAuth.instance.currentUser;
      if (uCheck != null) {
        debugPrint(
          'Sign-in produced platform error, but currentUser is present uid=${uCheck.uid}. Navigating to Home.',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Signed in as ${uCheck.email}')));
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => HomeScreen()),
          (route) => false,
        );
        return;
      }

      // Specific guidance for pigeon/type cast errors (common plugin mismatch symptom)

      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'user-not-found':
            setState(() => _emailError = 'No account found for this email');
            break;
          case 'wrong-password':
            setState(() => _passwordError = 'Incorrect password');
            break;
          default:
            _showError(e);
        }
      } else {
        final dialogMsg = isPigeonTypeError
            ? 'Internal platform error occurred during sign-in. This can happen when Firebase plugins are out of sync. Try running `flutter pub upgrade` and rebuilding the app.'
            : e.toString();

        if (mounted) {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Sign-in error'),
              content: SingleChildScrollView(child: Text(dialogMsg)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    if (mounted) setState(() => _loading = true);
    try {
      await _auth.signInWithGoogle();
    } catch (e) {
      if (e is AccountExistsWithDifferentCredential) {
        await _showLinkDialog(e.email);
      } else {
        _showError(e);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showLinkDialog(String email) async {
    final pwCtrl = TextEditingController();
    final res = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Link accounts'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'An account exists with the same email. Enter password to link Google to it:',
            ),
            SizedBox(height: 8),
            TextField(
              controller: pwCtrl,
              obscureText: true,
              decoration: InputDecoration(labelText: 'Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Link'),
          ),
        ],
      ),
    );

    if (res == true) {
      if (mounted) setState(() => _loading = true);
      try {
        await _auth.linkPendingCredentialWithEmailPassword(email, pwCtrl.text);
      } catch (e) {
        _showError(e);
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: BouncingScrollPhysics(),
          child: Column(
            children: [
              // Top curved header
              Container(
                height: 220,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6FB1FF), Color(0xFF2D79FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(48),
                    bottomRight: Radius.circular(48),
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Phone Shop',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Looking for a next Phone',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 18),

              // Form card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Toggle row (Login / Sign In) simplified
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Color(0xFF2D79FF),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Log In',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              TextButton(
                                onPressed: () =>
                                    Navigator.pushNamed(context, '/register'),
                                child: Text(
                                  'Sign In',
                                  style: TextStyle(
                                    color: Colors.blueGrey,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 18),

                          // Email
                          TextFormField(
                            controller: _emailCtrl,
                            decoration: InputDecoration(
                              hintText: 'Username or Email',
                              errorText: _emailError,
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(28),
                                borderSide: BorderSide(
                                  color: Color(0xFFB8CDEB),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(28),
                                borderSide: BorderSide(
                                  color: Color(0xFF2D79FF),
                                  width: 2,
                                ),
                              ),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) => (v == null || !v.contains('@'))
                                ? 'Enter a valid email'
                                : null,
                          ),

                          SizedBox(height: 12),

                          // Password
                          TextFormField(
                            controller: _passCtrl,
                            decoration: InputDecoration(
                              hintText: 'Password',
                              errorText: _passwordError,
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(28),
                                borderSide: BorderSide(
                                  color: Color(0xFFB8CDEB),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(28),
                                borderSide: BorderSide(
                                  color: Color(0xFF2D79FF),
                                  width: 2,
                                ),
                              ),
                            ),
                            obscureText: true,
                            validator: (v) => (v == null || v.length < 6)
                                ? 'Password too short'
                                : null,
                          ),

                          SizedBox(height: 18),

                          // Primary login button
                          ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF2D79FF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 14),
                              elevation: 4,
                            ),
                            child: _loading
                                ? SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'Log In',
                                    style: TextStyle(fontSize: 16),
                                  ),
                          ),

                          SizedBox(height: 12),

                          Center(
                            child: Text(
                              'or',
                              style: TextStyle(color: Colors.black54),
                            ),
                          ),

                          SizedBox(height: 12),

                          // Social icons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: () {},
                                child: CircleAvatar(
                                  backgroundColor: Colors.blue[800],
                                  child: Icon(
                                    Icons.facebook,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              GestureDetector(
                                onTap: () {},
                                child: CircleAvatar(
                                  backgroundColor: Colors.lightBlue,
                                  child: Icon(
                                    Icons.alternate_email,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              GestureDetector(
                                onTap: _google,
                                child: CircleAvatar(
                                  backgroundColor: Colors.white,
                                  child: Image.asset(
                                    'assets/icons/google.png',
                                    height: 22,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 12),

                          TextButton(
                            onPressed: () =>
                                Navigator.pushNamed(context, '/forgot'),
                            child: Text(
                              'Privacy policy · Term of service',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
