import 'package:flutter/material.dart';
import 'dart:async';
import '../utils/ui_helpers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/local_auth.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'home_screen.dart';
import '../widgets/auth_header.dart';

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
  bool _obscurePassword = true;
  String? _inlineError;
  Timer? _inlineErrorTimer;

  void _showError(Object e) {
    final msg = _auth.friendlyError(e);
    _displayError(msg);
    debugPrint('LoginScreen._showError: $e');
  }

  void _displayError(String message) {
    // show inline banner
    if (mounted) {
      setState(() => _inlineError = message);
    }
    // also show a short, themed SnackBar for accessibility (only while mounted)
    if (mounted) {
      showAppSnackBar(
        context,
        message,
        error: true,
        duration: const Duration(seconds: 4),
      );
    }

    // auto-clear inline banner after a short delay (cancel previous timer)
    _inlineErrorTimer?.cancel();
    _inlineErrorTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _inlineError = null);
    });
  }

  @override
  void dispose() {
    _inlineErrorTimer?.cancel();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Signed in as ${u.email}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: Theme.of(context).colorScheme.secondary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 3),
            ),
          );

          // Persist account locally for offline sign-in convenience.
          try {
            final username = u.displayName ?? _emailCtrl.text.split('@').first;
            await LocalAuth.saveAccount(
              email: _emailCtrl.text.trim(),
              username: username,
              password: _passCtrl.text,
            );
            debugPrint('Saved account to Hive for offline login');
          } catch (localErr) {
            debugPrint('Failed to save local account after sign-in: $localErr');
          }

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

      // Offline fallback: verify against locally stored credentials (Hive)
      try {
        final ok = await LocalAuth.verifyCredentials(
          _emailCtrl.text.trim(),
          _passCtrl.text,
        );
        if (ok) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Signed in offline as ${_emailCtrl.text.trim()}'),
            ),
          );
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => HomeScreen()),
            (route) => false,
          );
          return;
        }
      } catch (localErr) {
        debugPrint('Offline credential check failed: $localErr');
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
          _displayError(dialogMsg);
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    if (mounted) setState(() => _loading = true);
    try {
      final cred = await _auth.signInWithGoogle();
      User? u = FirebaseAuth.instance.currentUser ?? cred?.user;
      if (u != null) {
        // Ensure Firestore profile exists (same as email flow)
        try {
          final uid = u.uid;
          final doc = await FirestoreService.getDocument('users/$uid');
          if (doc == null || !doc.exists) {
            await FirestoreService.set('users/$uid', {
              'email': u.email,
              'role': 'user',
              'displayName': u.displayName ?? '',
              'createdAt': DateTime.now().toUtc().toIso8601String(),
            });
            debugPrint('Created missing Firestore profile for $uid');
          }
        } catch (profileErr) {
          debugPrint('Error loading/creating Firestore profile: $profileErr');
        }

        if (!mounted) return;
        showAppSnackBar(context, 'Signed in as ${u.email}');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => HomeScreen()),
          (route) => false,
        );
      }
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: BouncingScrollPhysics(),
          child: Column(
            children: [
              // Top curved header (compact)
              AuthHeader(
                title: 'Drug Store',
                subtitle: 'Welcome back! please login to your account',
                height: 160,
                titleFontSize: 20,
                subtitleFontSize: 12,
              ),

              SizedBox(height: 12),

              // Primary login button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Card(
                  color: theme.cardColor,
                  elevation: theme.cardTheme.elevation ?? 6,
                  shape:
                      theme.cardTheme.shape ??
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Inline error banner
                          if (_inlineError != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.error,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _inlineError!,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.white70,
                                      ),
                                      onPressed: () =>
                                          setState(() => _inlineError = null),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          // Toggle row (Login / Sign In) simplified
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 260),
                                transitionBuilder: (child, anim) =>
                                    FadeTransition(
                                      opacity: anim,
                                      child: ScaleTransition(
                                        scale: anim,
                                        child: child,
                                      ),
                                    ),
                                child: Container(
                                  key: const ValueKey('active_login'),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cs.primary,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Log In',
                                    style: TextStyle(
                                      color: cs.onPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              TextButton(
                                onPressed: () =>
                                    Navigator.pushNamed(context, '/register'),
                                child: Text(
                                  'Register',
                                  style: TextStyle(
                                    color: cs.onSurface.withValues(alpha: 0.7),
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
                              hintText: 'Email',
                              hintStyle: TextStyle(fontSize: 12),
                              errorText: _emailError,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 12,
                              ),
                            ),
                            style: TextStyle(fontSize: 12),
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Enter an email';
                              }
                              final email = v.trim();
                              final re = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$");
                              return re.hasMatch(email)
                                  ? null
                                  : 'Enter a valid email';
                            },
                          ),

                          SizedBox(height: 12),

                          // (Forgot password link moved below login button)

                          // Password
                          TextFormField(
                            controller: _passCtrl,
                            decoration: InputDecoration(
                              hintText: 'Password',
                              hintStyle: TextStyle(fontSize: 12),
                              errorText: _passwordError,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 12,
                              ),
                              suffixIcon: AnimatedRotation(
                                turns: _obscurePassword ? 0.0 : 0.5,
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeInOut,
                                child: IconButton(
                                  tooltip: _obscurePassword
                                      ? 'Show password'
                                      : 'Hide password',
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.65),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                            ),
                            style: TextStyle(fontSize: 12),
                            obscureText: _obscurePassword,
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Enter a password';
                              }
                              if (v.length < 6) {
                                return 'Password too short';
                              }
                              final hasDigit = RegExp(r"[0-9]").hasMatch(v);
                              if (!hasDigit) {
                                return 'Password must include a number (0-9)';
                              }
                              return null;
                            },
                          ),

                          SizedBox(height: 18),

                          // Primary login button (compact)
                          ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: cs.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              elevation: 4,
                            ),
                            child: _loading
                                ? SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'Log In',
                                    style: TextStyle(fontSize: 14),
                                  ),
                          ),

                          SizedBox(height: 12),

                          // Forgot password (left aligned under login button)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/forgot'),
                              child: Text('Forgot password?'),
                            ),
                          ),

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
                              SizedBox(width: 12),
                              GestureDetector(
                                onTap: _google,
                                child: CircleAvatar(
                                  backgroundColor: const Color.fromARGB(
                                    255,
                                    206,
                                    220,
                                    223,
                                  ),
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
                                Navigator.pushNamed(context, '/privacy'),
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
