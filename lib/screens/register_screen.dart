import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final AuthService _auth = AuthService();
  bool _loading = false;

  void _showError(Object e) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(_auth.friendlyError(e))));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passCtrl.text != _confirmCtrl.text) {
      return _showError('Passwords do not match');
    }
    setState(() => _loading = true);
    try {
      debugPrint('Attempting to create user: ${_emailCtrl.text.trim()}');
      final cred = await _auth.registerWithEmail(
        _emailCtrl.text.trim(),
        _passCtrl.text,
      );

      debugPrint('Register returned credential: user=${cred.user?.uid}');

      // Ensure we actually have a user returned from Firebase.
      if (cred.user == null) {
        throw FirebaseAuthException(
          code: 'user-creation-failed',
          message: 'User creation returned no user object',
        );
      }

      // Create a user profile document in Firestore using the generated UID.
      try {
        final uid = cred.user!.uid;
        final profile = {
          'email': _emailCtrl.text.trim(),
          'role': 'user',
          'displayName': null,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        };
        await FirestoreService.set('users/$uid', profile);
        debugPrint('Created Firestore profile for user $uid');
      } catch (e) {
        debugPrint('Failed to create Firestore user profile: $e');
      }

      // Try signing out, but don't treat sign-out failures as registration failures.
      try {
        await _auth.signOut();
      } catch (signOutErr) {
        debugPrint('Sign-out after register failed: $signOutErr');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Account created. Please sign in.')),
        );
        Navigator.pop(context, _emailCtrl.text.trim());
      }
    } catch (e, st) {
      final errText = e.toString();
      final isPigeonTypeError =
          errText.contains('Pigeon') || errText.contains('is not a subtype of');
      debugPrint(
        'Register error: ${isPigeonTypeError ? 'platform/plugin type error' : e}',
      );
      if (!isPigeonTypeError) debugPrintStack(stackTrace: st);

      // In some cases createUserWithEmailPassword can throw (network/race)
      // while the account is actually created on the server. We'll attempt
      // a few recovery strategies in order:
      // 1) If `currentUser` is set, treat as success.
      // 2) Try signing in with the same credentials (sometimes the SDK can
      //    succeed even when create throws). If sign-in succeeds, treat as
      //    success and sign out.
      // 3) Try fetching sign-in methods for the email (several attempts).
      try {
        final email = _emailCtrl.text.trim();
        final password = _passCtrl.text;

        // 1) Check currentUser quickly
        await Future.delayed(const Duration(milliseconds: 250));
        final current = FirebaseAuth.instance.currentUser;
        if (current != null) {
          debugPrint('User exists according to currentUser: ${current.uid}');
          try {
            await _auth.signOut();
          } catch (_) {}
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Account created. Please sign in.')),
            );
            Navigator.pop(context, email);
            setState(() => _loading = false);
            return;
          }
        }

        // 2) Try signing in with the credentials used to register.
        // This can succeed if the server created the account but the client
        // experienced a transient error during creation.
        try {
          await Future.delayed(const Duration(milliseconds: 300));
          final signInCred = await _auth.signInWithEmail(email, password);
          if (signInCred.user != null) {
            debugPrint(
              'Sign-in after register error succeeded: ${signInCred.user!.uid}',
            );
            try {
              await _auth.signOut();
            } catch (_) {}
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Account created. Please sign in.')),
              );
              Navigator.pop(context, email);
              setState(() => _loading = false);
              return;
            }
          }
        } catch (signInErr) {
          debugPrint('Sign-in attempt after register failed: $signInErr');
          // continue to fetchSignInMethods attempts
        }

        // 3) Fetch sign-in methods with multiple attempts/backoff.
        const attempts = 5;
        for (var i = 0; i < attempts; i++) {
          try {
            // exponential backoff
            await Future.delayed(Duration(milliseconds: 400 * (i + 1)));
            final methods = await FirebaseAuth.instance
                .fetchSignInMethodsForEmail(email);
            if (methods.isNotEmpty) {
              debugPrint(
                'User exists according to fetchSignInMethods: $methods',
              );
              try {
                await _auth.signOut();
              } catch (_) {}
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Account created. Please sign in.')),
                );
                if (mounted) {
                  Navigator.pop(context, email);
                  setState(() => _loading = false);
                  return;
                }
              }
            }
          } catch (inner) {
            debugPrint('fetchSignInMethods attempt ${i + 1} failed: $inner');
          }
        }
      } catch (checkErr) {
        debugPrint('Error checking sign-in status: $checkErr');
      }

      String message;
      if (e is FirebaseAuthException) {
        message = _auth.friendlyError(e);
      } else if (e is PlatformException) {
        message = e.message ?? 'A platform error occurred.';
      } else {
        message = 'Could not create account. Please try again.';
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    setState(() => _loading = true);
    try {
      await _auth.signInWithGoogle();
      if (!mounted) return;
      Navigator.pop(context, null);
    } catch (e) {
      if (e is AccountExistsWithDifferentCredential) {
        showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('Account exists'),
            content: Text(
              'An account already exists with this email. Please sign in with email/password and link Google in account settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
            ],
          ),
        );
      } else {
        _showError(e);
      }
    } finally {
      setState(() => _loading = false);
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
              Container(
                height: 200,
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
                        'Create Account',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 18),

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
                          TextFormField(
                            controller: _emailCtrl,
                            decoration: InputDecoration(
                              hintText: 'Email',
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

                          TextFormField(
                            controller: _passCtrl,
                            decoration: InputDecoration(
                              hintText: 'Password',
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

                          SizedBox(height: 12),

                          TextFormField(
                            controller: _confirmCtrl,
                            decoration: InputDecoration(
                              hintText: 'Confirm Password',
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
                          ),

                          SizedBox(height: 18),

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
                                    'Create Account',
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

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
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
