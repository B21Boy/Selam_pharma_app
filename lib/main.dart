import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'models/medicine.dart';
import 'models/report.dart';
import 'providers/pharmacy_provider.dart';
import 'services/sync_service.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Warning: Could not load .env: $e');
  }
  await Firebase.initializeApp();
  await Hive.initFlutter();
  Hive.registerAdapter(MedicineAdapter());
  Hive.registerAdapter(ReportAdapter());

  // Start background sync between Hive, Firestore and Cloudinary
  // We'll create and initialize SyncService here so it starts after Firebase init.
  SyncService? syncService;
  try {
    syncService = SyncService();
    await syncService.init();
  } catch (e) {
    debugPrint('Warning: SyncService failed to init: $e');
  }

  final settingsBox = await Hive.openBox('settings');

  runApp(MyApp(settingsBox: settingsBox, syncService: syncService));
}

class MyApp extends StatelessWidget {
  final Box settingsBox;
  final SyncService? syncService;

  const MyApp({super.key, required this.settingsBox, this.syncService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider(settingsBox)),
        ChangeNotifierProvider(
          create: (context) => PharmacyProvider()..initBoxes(),
        ),
        // Provide SyncService so other widgets can access it if needed.
        Provider<SyncService?>.value(value: syncService),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'SHMed',
            theme: ThemeData(
              primaryColor: Color(0xFF007BFF), // Medical blue
              colorScheme: ColorScheme.light(
                primary: Color(0xFF007BFF),
                secondary: Color(0xFF28A745), // Pharmacy green
                surface: Colors.white,
                onPrimary: Colors.white,
                onSecondary: Colors.white,
                onSurface: Colors.black87,
              ),
              scaffoldBackgroundColor: Color(0xFFF8F9FA),
              appBarTheme: AppBarThemeData(
                backgroundColor: Color(0xFF007BFF),
                foregroundColor: Colors.white,
                elevation: 4,
                centerTitle: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
              ),
              cardTheme: CardThemeData(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                shadowColor: Colors.black12,
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFFDEE2E6)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFFDEE2E6)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFF007BFF), width: 2),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF007BFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  elevation: 2,
                ),
              ),
              bottomNavigationBarTheme: BottomNavigationBarThemeData(
                backgroundColor: Colors.white,
                selectedItemColor: Color(0xFF007BFF),
                unselectedItemColor: Colors.grey,
                elevation: 8,
                type: BottomNavigationBarType.fixed,
              ),
            ),
            darkTheme: ThemeData.dark().copyWith(
              primaryColor: Color(0xFF007BFF),
              colorScheme: ColorScheme.dark(
                primary: Color(0xFF007BFF),
                secondary: Color(0xFF28A745),
                surface: Color(0xFF1E1E1E),
                onPrimary: Colors.white,
                onSecondary: Colors.white,
                onSurface: Colors.white70,
              ),
              scaffoldBackgroundColor: Color(0xFF121212),
              appBarTheme: AppBarThemeData(
                backgroundColor: Color(0xFF007BFF),
                foregroundColor: Colors.white,
                elevation: 4,
                centerTitle: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
              ),
              cardTheme: CardThemeData(
                color: Color(0xFF2D2D2D),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                shadowColor: Colors.black38,
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Color(0xFF2D2D2D),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFF007BFF), width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[600]!, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFF007BFF), width: 2),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF007BFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  elevation: 2,
                ),
              ),
              bottomNavigationBarTheme: BottomNavigationBarThemeData(
                backgroundColor: Color(0xFF1E1E1E),
                selectedItemColor: Color(0xFF007BFF),
                unselectedItemColor: Colors.grey[400],
                elevation: 8,
                type: BottomNavigationBarType.fixed,
              ),
            ),
            themeMode: themeProvider.themeMode,
            routes: {
              '/login': (_) => LoginScreen(),
              '/register': (_) => RegisterScreen(),
              '/forgot': (_) => ForgotPasswordScreen(),
            },
            builder: (context, child) {
              final sync = Provider.of<SyncService?>(context);
              return StreamBuilder<String?>(
                stream: sync?.errorStream,
                builder: (context, snap) {
                  final raw = snap.data;
                  if (raw == null) return child!;

                  final err = raw.split('\n').first;
                  final lowered = err.toLowerCase();
                  final isPermDenied =
                      lowered.contains('permission') &&
                      lowered.contains('denied');

                  // Sanitize messages shown to users. Log raw error for debugging.
                  debugPrint('SyncService reported error: $err');
                  final message = isPermDenied
                      ? 'Firestore permission denied — your account cannot access this data. Check your Firestore rules or sign out.'
                      : 'Sync error — check your network connection and Firestore rules. You can dismiss this message.';

                  return Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      MaterialBanner(
                        content: Text(message),
                        backgroundColor: Colors.red.shade700,
                        actions: [
                          if (isPermDenied) ...[
                            TextButton(
                              onPressed: () async {
                                try {
                                  await AuthService().signOut();
                                  Navigator.of(context).pushNamedAndRemoveUntil(
                                    '/login',
                                    (route) => false,
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Sign out failed: $e'),
                                    ),
                                  );
                                }
                              },
                              child: const Text(
                                'Sign out',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                          TextButton(
                            onPressed: () {
                              sync?.clearError();
                            },
                            child: const Text(
                              'Dismiss',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      Expanded(child: child!),
                    ],
                  );
                },
              );
            },
            onGenerateRoute: (settings) {
              if (settings.name == '/auth') {
                return PageRouteBuilder(
                  settings: settings,
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      const AuthGate(),
                  transitionDuration: const Duration(milliseconds: 600),
                  transitionsBuilder:
                      (_, animation, secondaryAnimation, child) {
                        final fade = CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeInOut,
                        );
                        final offset =
                            Tween<Offset>(
                              begin: const Offset(0, 0.08),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOut,
                              ),
                            );
                        return FadeTransition(
                          opacity: fade,
                          child: SlideTransition(
                            position: offset,
                            child: child,
                          ),
                        );
                      },
                );
              }
              return null;
            },
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = snapshot.data;
        if (user == null) return LoginScreen();

        return FutureBuilder<bool>(
          future: _verifyUser(user),
          builder: (context, verifySnap) {
            if (verifySnap.connectionState == ConnectionState.waiting) {
              return Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (verifySnap.data == true) return HomeScreen();
            return LoginScreen();
          },
        );
      },
    );
  }

  Future<bool> _verifyUser(User user) async {
    try {
      await user.reload();
      final u = FirebaseAuth.instance.currentUser;
      debugPrint('AuthGate._verifyUser: reload done uid=${u?.uid}');
      if (u == null) {
        debugPrint('AuthGate._verifyUser: currentUser is null');
        return false;
      }
      if (u.isAnonymous) {
        debugPrint('AuthGate._verifyUser: anonymous user -> signing out');
        await FirebaseAuth.instance.signOut();
        return false;
      }
      // Force-refresh ID token to ensure server-side account state (deleted/disabled)
      try {
        await u.getIdToken(true);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' ||
            e.code == 'user-disabled' ||
            e.code == 'invalid-user-token') {
          debugPrint(
            'AuthGate._verifyUser: idToken refresh failed (${e.code}) — signing out',
          );
          await FirebaseAuth.instance.signOut();
          return false;
        }
        rethrow;
      }
      // Some platforms may report empty providerData briefly after sign-in.
      // Avoid signing the user out immediately; accept the user if a valid uid
      // exists and is not anonymous.
      if (u.providerData.isEmpty) {
        debugPrint(
          'AuthGate._verifyUser: providerData empty but uid present, accepting user',
        );
        return true;
      }
      return true;
    } catch (e) {
      final errText = e.toString();
      final isPigeonTypeError =
          errText.contains('Pigeon') || errText.contains('is not a subtype of');
      if (isPigeonTypeError) {
        debugPrint(
          'AuthGate._verifyUser: plugin/platform type error (Pigeon/type-cast)',
        );
      } else {
        debugPrint('AuthGate._verifyUser: exception $e');
      }
      final u = FirebaseAuth.instance.currentUser;
      if (isPigeonTypeError && u != null && !u.isAnonymous) {
        debugPrint(
          'AuthGate._verifyUser: plugin type error but currentUser present; accepting user uid=${u.uid}',
        );
        return true;
      }
      await FirebaseAuth.instance.signOut();
      return false;
    }
  }
}
