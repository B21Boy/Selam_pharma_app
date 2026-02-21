import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  bool _navigated = false;
  final String _appName = 'Drugo';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(
      begin: 0.95,
      end: 1.02,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
    _start();
    // keep simple splash: no typing animation, show full app name
  }

  Future<void> _start() async {
    final authFuture = _isLoggedIn();
    // keep splash visible for at least 1.4s while auth check runs
    await Future.delayed(const Duration(milliseconds: 1400));
    final loggedIn = await authFuture;
    if (!mounted) return;
    _navigateNext(loggedIn);
  }

  // Check Firebase auth/token validity
  Future<bool> _isLoggedIn() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      // Ensure token is fresh and account is valid
      await user.reload();
      final u = FirebaseAuth.instance.currentUser;
      if (u == null) return false;
      if (u.isAnonymous) {
        await FirebaseAuth.instance.signOut();
        return false;
      }
      try {
        await u.getIdToken(true);
      } on FirebaseAuthException catch (e) {
        debugPrint('Splash _isLoggedIn: token refresh failed ${e.code}');
        await FirebaseAuth.instance.signOut();
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('Splash _isLoggedIn exception: $e');
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
      // If Firebase auth check failed (likely offline), check for locally
      // stored account credentials and allow offline routing to home.
      try {
        final box = await Hive.openBox('accounts');
        if (box.isNotEmpty) return true;
      } catch (boxErr) {
        debugPrint('Splash: failed opening accounts box: $boxErr');
      }
      return false;
    }
  }

  void _navigateNext(bool loggedIn) {
    if (_navigated) return;
    if (!mounted) return;
    _navigated = true;
    final routeName = loggedIn ? '/home' : '/auth';
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, anim, secAnim) => _RouteRedirector(routeName),
        transitionsBuilder: (context, anim, secAnim, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: _scale,
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Circular logo container
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2D79FF), Color(0xFF6FB1FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(child: _buildLogo()),
                  ),
                  const SizedBox(height: 18),
                  // App name
                  Text(
                    _appName,
                    style: const TextStyle(
                      color: Color(0xFF2D79FF),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      fontSize: 34,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Care. Fast. Simple.',
                    style: TextStyle(color: Colors.black54, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(Color(0xFF2D79FF)),
                      strokeWidth: 2.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'v1.0.0',
                    style: TextStyle(color: const Color.fromRGBO(0, 0, 0, 0.6)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    const assetPath = 'assets/icons/app_logo.png';
    return ClipOval(
      child: Image.asset(
        assetPath,
        width: 110,
        height: 110,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => CircleAvatar(
          radius: 55,
          backgroundColor: Colors.white,
          child: Icon(Icons.local_pharmacy, size: 48, color: Color(0xFF2D79FF)),
        ),
      ),
    );
  }
}

// Helper widget that immediately redirects to a named route when built.
class _RouteRedirector extends StatelessWidget {
  final String routeName;
  const _RouteRedirector(this.routeName);

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Navigator.of(context).canPop()) return;
      Navigator.of(context).pushReplacementNamed(routeName);
    });
    return const SizedBox.shrink();
  }
}
