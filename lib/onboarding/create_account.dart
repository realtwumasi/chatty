import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../home/home_page.dart';
import '../model/responsive_helper.dart';
import '../services/chat_repository.dart';

class CreateAccount extends ConsumerStatefulWidget {
  const CreateAccount({super.key});

  @override
  ConsumerState<CreateAccount> createState() => _CreateAccountState();
}

class _CreateAccountState extends ConsumerState<CreateAccount> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _email = TextEditingController();

  void _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await ref.read(chatRepositoryProvider).register(
          _username.text.trim(),
          _email.text.trim(),
          _password.text.trim()
      );

      if (mounted) {
        Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
                (route) => false
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceAll('ApiException:', '').trim();
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            )
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(isLoadingProvider);
    // ... UI Code remains similar ...
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final inputFillColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey.shade300;
    final hintColor = isDark ? Colors.grey[500] : Colors.grey.shade400;
    final isDesktop = Responsive.isDesktop(context);
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
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (val) {
                          if (val == null || val.isEmpty) return "Required";
                          final validCharacters = RegExp(r'^[\w.@+-]+$');
                          if (!validCharacters.hasMatch(val)) {
                            return "No spaces or special chars allowed";
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: "Username",
                          labelStyle: TextStyle(color: hintColor),
                          filled: true,
                          fillColor: inputFillColor,
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1A60FF), width: 1.5)),
                        ),
                      ),
                      SizedBox(height: 16.h),

                      TextFormField(
                        controller: _email,
                        style: TextStyle(color: textColor),
                        validator: (val) => !val!.contains('@') ? "Invalid Email" : null,
                        decoration: InputDecoration(
                          labelText: "Email",
                          labelStyle: TextStyle(color: hintColor),
                          filled: true,
                          fillColor: inputFillColor,
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1A60FF), width: 1.5)),
                        ),
                      ),
                      SizedBox(height: 16.h),

                      TextFormField(
                        controller: _password,
                        obscureText: true,
                        style: TextStyle(color: textColor),
                        validator: (val) => val!.length < 1 ? "Required" : null,
                        decoration: InputDecoration(
                          labelText: "Password",
                          labelStyle: TextStyle(color: hintColor),
                          filled: true,
                          fillColor: inputFillColor,
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1A60FF), width: 1.5)),
                        ),
                      ),
                      SizedBox(height: 25.h),

                      ElevatedButton(
                        onPressed: isLoading ? null : _handleRegister,
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(double.infinity, buttonHeight),
                          backgroundColor: const Color(0xFF1A60FF),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text("Create Account", style: TextStyle(color: Colors.white, fontSize: Responsive.fontSize(context, 16))),
                      ),
                      // ...
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