import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';
import '../home/home_page.dart';
import '../model/responsive_helper.dart';
import '../services/chat_repository.dart';
import 'sign_in_page.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {

  @override
  void initState() {
    super.initState();
    _startLoading();
  }

  void _startLoading() async {
    // Start initialization immediately so theme loads ASAP
    final initTask = ref.read(chatRepositoryProvider).initialize();
    
    // Ensure we show splash for at least 2 seconds
    final minDelay = Future.delayed(const Duration(seconds: 2));

    // Wait for both
    final results = await Future.wait([initTask, minDelay]);
    final isLoggedIn = results[0] as bool;

    if (!mounted) return;

    if (isLoggedIn) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const SignInPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final isDesktop = Responsive.isDesktop(context);
    final double lottieSize = isDesktop ? 300.0 : 250.w;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: lottieSize,
              height: lottieSize,
              child: Lottie.asset(
                "asset/lotties/Chat Messenger/animations/12345.json",
                fit: BoxFit.contain,
                frameRate: FrameRate.max,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                      Icons.chat_bubble_rounded,
                      size: isDesktop ? 120 : 100.w,
                      color: const Color(0xFF1A60FF)
                  );
                },
              ),
            ),
            SizedBox(height: 15.h),
            AnimatedTextKit(
              key: ValueKey(Theme.of(context).brightness),
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