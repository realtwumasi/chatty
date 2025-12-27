import 'dart:async';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';
import '../model/responsive_helper.dart';
import 'sign_in_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer(const Duration(seconds: 3), () {
      navigateToSignIn();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void navigateToSignIn() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const SignInPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Theme Awareness
    final textColor = Theme.of(context).colorScheme.onSurface;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    // Responsive Logic
    final isDesktop = Responsive.isDesktop(context);
    final double lottieSize = isDesktop ? 300.0 : 250.w;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Optimization: Use SizedBox for explicit dimensions to prevent Web layout shifts
            SizedBox(
              width: lottieSize,
              height: lottieSize,
              child: Lottie.asset(
                "asset/lotties/Chat Messenger/animations/12345.json",
                fit: BoxFit.contain,
                // Optimization: Force high frame rate for smoother web rendering
                frameRate: FrameRate.max,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                      Icons.chat_bubble,
                      size: isDesktop ? 100 : 80.w,
                      color: const Color(0xFF1A60FF)
                  );
                },
              ),
            ),
            SizedBox(height: 15.h),
            AnimatedTextKit(
              animatedTexts: [
                TypewriterAnimatedText(
                  'Chatty',
                  textStyle: TextStyle(
                    fontSize: Responsive.fontSize(context, 32),
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    decoration: TextDecoration.none,
                  ),
                  speed: const Duration(milliseconds: 350),
                ),
              ],
              totalRepeatCount: 1,
            ),
          ],
        ),
      ),
    );
  }
}