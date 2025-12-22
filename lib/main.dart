import 'package:chatty/onboarding/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize ScreenUtil for responsive design based on your design size
    return ScreenUtilInit(
      designSize: const Size(393, 852),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Chatty',
          theme: ThemeData(
            colorScheme: const ColorScheme(
              brightness: Brightness.light,
              primary: Colors.white,
              onPrimary: Color(0xFF1A60FF),
              secondary: Color(0xFF1A60FF),
              onSecondary: Colors.white,
              error: Colors.red,
              onError: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            useMaterial3: true,
            // Setting a consistent font family if needed, defaulting to system
            scaffoldBackgroundColor: Colors.white,
          ),
          home: SplashScreen(),
        );
      },
    );
  }
}