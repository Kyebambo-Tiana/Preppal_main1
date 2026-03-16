import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prepal2/presentation/providers/auth_provider.dart';
import 'package:prepal2/presentation/providers/business_provider.dart';
import 'package:prepal2/presentation/screens/auth/login_screen.dart';
import 'package:prepal2/presentation/screens/auth/signup_screen.dart';
import 'package:prepal2/presentation/screens/auth/business_details_screen.dart';
import 'package:prepal2/presentation/screens/main_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kLogoTintColor = Color(0xFFFF6B35);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _kHasSeenWelcome = 'has_seen_welcome';
  bool _showYellowSplash = false;

  @override
  void initState() {
    super.initState();
    _runSplashSequence();
  }

  Future<void> _runSplashSequence() async {
    const logoSplashDuration = Duration(seconds: 2);
    const yellowSplashDuration = Duration(seconds: 6);

    await Future.delayed(logoSplashDuration);
    if (!mounted) return;

    setState(() {
      _showYellowSplash = true;
    });

    await Future.delayed(yellowSplashDuration);
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    final businessProvider = context.read<BusinessProvider>();

    await _waitForAuthResolution(authProvider);
    if (!mounted) return;

    if (authProvider.status == AuthStatus.authenticated) {
      await businessProvider.loadBusinesses();
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => businessProvider.hasBusiness
              ? const MainShell()
              : const BusinessDetailsScreen(),
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final hasSeenWelcome = prefs.getBool(_kHasSeenWelcome) ?? false;

    if (hasSeenWelcome) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }

    await prefs.setBool(_kHasSeenWelcome, true);

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const WelcomeScreen()));
  }

  Future<void> _waitForAuthResolution(AuthProvider authProvider) async {
    var attempts = 0;
    while (attempts < 20 &&
        (authProvider.status == AuthStatus.initial ||
            authProvider.status == AuthStatus.loading)) {
      await Future.delayed(const Duration(milliseconds: 150));
      attempts++;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _showYellowSplash
          ? const Color(0xFFF0B516)
          : Colors.white,
      body: _showYellowSplash
          ? LayoutBuilder(
              builder: (context, constraints) {
                final logoSize = constraints.maxWidth * 0.45;

                return Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        'assets/app_splash.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                    Align(
                      alignment: const Alignment(0, -0.47),
                      child: Container(
                        width: logoSize + 8,
                        height: logoSize + 8,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Image.asset(
                          'assets/logo.png',
                          width: logoSize,
                          height: logoSize,
                          color: kLogoTintColor,
                          colorBlendMode: BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ],
                );
              },
            )
          : Center(
              child: Image.asset(
                'assets/logo.png',
                width: 170,
                height: 170,
                color: kLogoTintColor,
                colorBlendMode: BlendMode.srcIn,
              ),
            ),
    );
  }
}

// --------------------------------------------------
// Welcome Screen (first screen from wireframe)
// --------------------------------------------------

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 2),

                      // PrepPal Logo
                      Image.asset(
                        'assets/logo.png',
                        width: 200,
                        height: 200,
                        color: kLogoTintColor,
                        colorBlendMode: BlendMode.srcIn,
                      ),

                      const SizedBox(height: 16),

                      const Text(
                        'Welcome',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF212121),
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'PrepPal is here to make prepping more\n'
                        'effective and profitable',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF7A7A7A),
                          height: 1.4,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'AI powered app to help you cut down wastage and\n'
                        'optimized your prepping for your business',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9E9E9E),
                          height: 1.4,
                        ),
                      ),

                      const Spacer(flex: 2),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SizedBox(
                            width: 100,
                            height: 40,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LoginScreen(),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F7A6B),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Log in',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          SizedBox(
                            width: 100,
                            height: 40,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SignupScreen(),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE8F5E9),
                                foregroundColor: const Color(0xFF2E7D32),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Sign up',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
