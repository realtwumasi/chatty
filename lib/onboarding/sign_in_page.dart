import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../home/home_page.dart';
import '../model/responsive_helper.dart';
import '../services/chat_repository.dart';
import 'create_account.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await ref.read(chatRepositoryProvider).login(_username.text.trim(), _password.text.trim());

      if (mounted) {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomePage())
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Login Error: ${e.toString()}"),
              backgroundColor: Colors.red,
            )
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch loading state
    final isLoading = ref.watch(isLoadingProvider);

    // ... UI Code remains largely the same, just removed local _isLoading state ...
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final inputFillColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey.shade300;
    final hintColor = isDark ? Colors.grey[500] : Colors.grey.shade400;

    final bool isDesktop = Responsive.isDesktop(context);
    final double buttonHeight = isDesktop ? 50 : 50.h;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: SingleChildScrollView(
            child: ResponsiveContainer(
              maxWidth: 450,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 0 : 20.w),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ... Branding ...
                      AnimatedTextKit(
                        animatedTexts: [
                          TypewriterAnimatedText(
                            'Chatty',
                            textStyle: TextStyle(
                              fontSize: Responsive.fontSize(context, 32),
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                            speed: const Duration(milliseconds: 350),
                          ),
                        ],
                        totalRepeatCount: 1,
                      ),
                      SizedBox(height: 40.h),

                      TextFormField(
                        controller: _username,
                        style: TextStyle(color: textColor),
                        validator: (val) => val!.isEmpty ? "Username required" : null,
                        decoration: InputDecoration(
                          labelText: "Username",
                          labelStyle: TextStyle(color: hintColor),
                          filled: true,
                          fillColor: inputFillColor,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF1A60FF), width: 1.5),
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      TextFormField(
                        controller: _password,
                        obscureText: true,
                        style: TextStyle(color: textColor),
                        validator: (val) => val!.isEmpty ? "Password required" : null,
                        decoration: InputDecoration(
                          labelText: "Password",
                          labelStyle: TextStyle(color: hintColor),
                          filled: true,
                          fillColor: inputFillColor,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF1A60FF), width: 1.5),
                          ),
                        ),
                      ),
                      SizedBox(height: 25.h),
                      ElevatedButton(
                        onPressed: isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(double.infinity, buttonHeight),
                          backgroundColor: const Color(0xFF1A60FF),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text("Log in", style: TextStyle(color: Colors.white, fontSize: Responsive.fontSize(context, 16))),
                      ),
                      SizedBox(height: 16.h),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const CreateAccount())
                          );
                        },
                        child: const Text("Create Account", style: TextStyle(color: Color(0xFF1A60FF))),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}