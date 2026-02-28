import 'package:flutter/material.dart';
import 'dart:async';
import '../utils/ui_helpers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../services/local_auth.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'home_screen.dart';
import '../widgets/auth_header.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final AuthService _auth = AuthService();
  bool _loading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  String? _inlineError;
  Timer? _inlineErrorTimer;

  void _showError(Object e) => _displayError(_auth.friendlyError(e));

  void _displayError(String message) {
    if (mounted) setState(() => _inlineError = message);

    if (mounted) {
      showAppSnackBar(
        context,
        message,
        error: true,
        duration: const Duration(seconds: 4),
      );
    }

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
    _confirmCtrl.dispose();
    super.dispose();
  }

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
          'displayName': _usernameCtrl.text.trim(),
          'username': _usernameCtrl.text.trim(),
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        };
        await FirestoreService.set('users/$uid', profile);
        debugPrint('Created Firestore profile for user $uid');
        // Persist account locally for offline sign-in convenience.
        try {
          await LocalAuth.saveAccount(
            email: _emailCtrl.text.trim(),
            username: _usernameCtrl.text.trim(),
            password: _passCtrl.text,
          );
          debugPrint('Saved account to Hive for offline login');
        } catch (localErr) {
          debugPrint('Failed to save local account: $localErr');
        }
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
        showAppSnackBar(context, 'Account created. Please sign in.');
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
            showAppSnackBar(context, 'Account created. Please sign in.');
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
              showAppSnackBar(context, 'Account created. Please sign in.');
              Navigator.pop(context, email);
              setState(() => _loading = false);
              return;
            }
          }
        } catch (signInErr) {
          debugPrint('Sign-in attempt after register failed: $signInErr');
          // continue to fetchSignInMethods attempts
        }

        // 3) The Firebase SDK removed fetchSignInMethodsForEmail in newer
        // releases. We won't attempt email-enumeration; fall through to
        // the general error handling below.
        debugPrint('Skipping fetchSignInMethodsForEmail checks (removed API)');
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
        showAppSnackBar(context, message, error: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    setState(() => _loading = true);
    try {
      final cred = await _auth.signInWithGoogle();
      User? u = FirebaseAuth.instance.currentUser ?? cred?.user;
      if (u != null) {
        // Ensure Firestore profile exists
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: BouncingScrollPhysics(),
          child: Column(
            children: [
              AuthHeader(
                title: 'Create Account',
                height: 160,
                titleFontSize: 20,
              ),

              SizedBox(height: 18),

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
                          // Toggle row: show Log In first, Sign In active second
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pushNamed(context, '/login'),
                                child: Text(
                                  'Log In',
                                  style: TextStyle(
                                    color: cs.onSurface.withValues(alpha: 0.75),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
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
                                  key: const ValueKey('active_signin'),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cs.primary,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Register',
                                    style: TextStyle(
                                      color: cs.onPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 18),

                          // Username (store into Firestore profile on register)
                          TextFormField(
                            controller: _usernameCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Username',
                              hintStyle: TextStyle(fontSize: 12),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 12,
                              ),
                              errorStyle: TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                            style: const TextStyle(fontSize: 12),
                            textCapitalization: TextCapitalization.words,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Please enter a username.';
                              }
                              if (v.trim().length < 3) {
                                return 'Username must be at least 3 characters.';
                              }
                              return null;
                            },
                          ),

                          SizedBox(height: 12),

                          TextFormField(
                            controller: _emailCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Email',
                              hintStyle: TextStyle(fontSize: 12),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 12,
                              ),
                              errorStyle: TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                            style: const TextStyle(fontSize: 12),
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Please enter your email.';
                              }
                              final email = v.trim();
                              final re = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$");
                              if (!re.hasMatch(email)) {
                                return 'Please enter a valid email address.';
                              }
                              return null;
                            },
                          ),

                          SizedBox(height: 12),

                          TextFormField(
                            controller: _passCtrl,
                            decoration: InputDecoration(
                              hintText: 'Password',
                              hintStyle: TextStyle(fontSize: 12),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 12,
                              ),
                              errorStyle: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                              suffixIcon: AnimatedRotation(
                                turns: _obscurePass ? 0.0 : 0.5,
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeInOut,
                                child: IconButton(
                                  tooltip: _obscurePass
                                      ? 'Show password'
                                      : 'Hide password',
                                  icon: Icon(
                                    _obscurePass
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.65),
                                  ),
                                  onPressed: () => setState(
                                    () => _obscurePass = !_obscurePass,
                                  ),
                                ),
                              ),
                            ),
                            style: const TextStyle(fontSize: 12),
                            obscureText: _obscurePass,
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Please enter a password.';
                              }
                              if (v.length < 6) {
                                return 'Password must be at least 6 characters.';
                              }
                              final hasDigit = RegExp(r"[0-9]").hasMatch(v);
                              if (!hasDigit) {
                                return 'Password must include a number.';
                              }
                              return null;
                            },
                          ),

                          SizedBox(height: 12),

                          TextFormField(
                            controller: _confirmCtrl,
                            decoration: InputDecoration(
                              hintText: 'Confirm Password',
                              hintStyle: TextStyle(fontSize: 12),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 12,
                              ),
                              errorStyle: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                              suffixIcon: AnimatedRotation(
                                turns: _obscureConfirm ? 0.0 : 0.5,
                                duration: Duration(milliseconds: 220),
                                curve: Curves.easeInOut,
                                child: IconButton(
                                  tooltip: _obscureConfirm
                                      ? 'Show password'
                                      : 'Hide password',
                                  icon: Icon(
                                    _obscureConfirm
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.65),
                                  ),
                                  onPressed: () => setState(
                                    () => _obscureConfirm = !_obscureConfirm,
                                  ),
                                ),
                              ),
                            ),
                            style: const TextStyle(fontSize: 12),
                            obscureText: _obscureConfirm,
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Please confirm your password.';
                              }
                              if (v != _passCtrl.text) {
                                return 'Passwords do not match.';
                              }
                              return null;
                            },
                          ),

                          SizedBox(height: 18),

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
                                    'Create Account',
                                    style: TextStyle(fontSize: 14),
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

                          // inline error message below the form fields
                          if (_inlineError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12.0),
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
