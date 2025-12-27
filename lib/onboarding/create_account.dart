import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../home/home_page.dart';
import '../model/responsive_helper.dart';
import '../services/chat_repository.dart';

class CreateAccount extends StatefulWidget {
  const CreateAccount({super.key});

  @override
  State<CreateAccount> createState() => _CreateAccountState();
}

class _CreateAccountState extends State<CreateAccount> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _email = TextEditingController();

  final ChatRepository _repository = ChatRepository();
  bool _isLoading = false;

  void _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      // API requires POST to /users/
      await _repository.register(
          _username.text.trim(),
          _email.text.trim(),
          _password.text.trim()
      );

      if (mounted) {
        // Registration successful & Logged in automatically
        Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
                (route) => false
        );
      }
    } catch (e) {
      if (mounted) {
        // Clean up error message for user display
        final msg = e.toString().replaceAll('ApiException:', '').trim();
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            )
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      SizedBox(height: isDesktop ? 8 : 8.h),
                      Text(
                        "Create Your Account",
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: Responsive.fontSize(context, 16),
                          color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                        ),
                      ),
                      SizedBox(height: isDesktop ? 40 : 40.h),

                      TextFormField(
                        controller: _username,
                        style: TextStyle(color: textColor),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (val) {
                          if (val == null || val.isEmpty) return "Required";
                          // Fix: Strict Regex to match API requirements
                          final validCharacters = RegExp(r'^[\w.@+-]+$');
                          if (!validCharacters.hasMatch(val)) {
                            return "No spaces or special chars allowed";
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: "Username",
                          labelStyle: TextStyle(color: hintColor, fontSize: Responsive.fontSize(context, 14)),
                          filled: true,
                          fillColor: inputFillColor,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(Responsive.radius(context, 12)),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(Responsive.radius(context, 12)),
                            borderSide: const BorderSide(color: Color(0xFF1A60FF), width: 1.5),
                          ),
                        ),
                      ),
                      SizedBox(height: isDesktop ? 16 : 16.h),

                      TextFormField(
                        controller: _email,
                        style: TextStyle(color: textColor),
                        validator: (val) => !val!.contains('@') ? "Invalid Email" : null,
                        decoration: InputDecoration(
                          labelText: "Email",
                          labelStyle: TextStyle(color: hintColor, fontSize: Responsive.fontSize(context, 14)),
                          filled: true,
                          fillColor: inputFillColor,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(Responsive.radius(context, 12)),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(Responsive.radius(context, 12)),
                            borderSide: const BorderSide(color: Color(0xFF1A60FF), width: 1.5),
                          ),
                        ),
                      ),
                      SizedBox(height: isDesktop ? 16 : 16.h),

                      TextFormField(
                        controller: _password,
                        obscureText: true,
                        style: TextStyle(color: textColor),
                        validator: (val) => val!.length < 1 ? "Required" : null,
                        decoration: InputDecoration(
                          labelText: "Password",
                          labelStyle: TextStyle(color: hintColor, fontSize: Responsive.fontSize(context, 14)),
                          filled: true,
                          fillColor: inputFillColor,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(Responsive.radius(context, 12)),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(Responsive.radius(context, 12)),
                            borderSide: const BorderSide(color: Color(0xFF1A60FF), width: 1.5),
                          ),
                        ),
                      ),
                      SizedBox(height: isDesktop ? 25 : 25.h),

                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleRegister,
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(double.infinity, buttonHeight),
                          backgroundColor: const Color(0xFF1A60FF),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text("Create Account", style: TextStyle(color: Colors.white, fontSize: Responsive.fontSize(context, 16))),
                      ),
                      SizedBox(height: isDesktop ? 16 : 16.h),

                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Already Have an account? Log in", style: TextStyle(color: Color(0xFF1A60FF))),
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