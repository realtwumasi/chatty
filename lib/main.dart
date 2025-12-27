import 'package:chatty/onboarding/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'externals/mock_data.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to MockService for Theme Changes
    return AnimatedBuilder(
      animation: MockService(),
      builder: (context, child) {
        final isDark = MockService().isDarkMode;

        return ScreenUtilInit(
          designSize: const Size(393, 852),
          minTextAdapt: true, // Crucial for desktop scaling
          splitScreenMode: true,
          builder: (_, child) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'Chatty',
              themeMode: isDark ? ThemeMode.dark : ThemeMode.light,

              theme: ThemeData(
                brightness: Brightness.light,
                scaffoldBackgroundColor: Colors.white,
                appBarTheme: const AppBarTheme(
                  backgroundColor: Colors.white,
                  iconTheme: IconThemeData(color: Colors.black),
                ),
                colorScheme: const ColorScheme.light(
                  primary: Colors.white,
                  onPrimary: Color(0xFF1A60FF),
                  secondary: Color(0xFF1A60FF),
                  surface: Colors.white,
                  onSurface: Colors.black,
                ),
                useMaterial3: true,
              ),

              darkTheme: ThemeData(
                brightness: Brightness.dark,
                scaffoldBackgroundColor: const Color(0xFF121212),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Color(0xFF121212),
                  iconTheme: IconThemeData(color: Colors.white),
                ),
                colorScheme: const ColorScheme.dark(
                  primary: Color(0xFF121212),
                  onPrimary: Colors.white,
                  secondary: Color(0xFF1A60FF),
                  surface: Color(0xFF1E1E1E),
                  onSurface: Colors.white,
                ),
                useMaterial3: true,
              ),

              home: const SplashScreen(),
            );
          },
        );
      },
    );
  }
}