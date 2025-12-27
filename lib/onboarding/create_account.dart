import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../model/responsive_helper.dart';

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

  @override
  Widget build(BuildContext context) {
    // Theme Awareness
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final inputFillColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey.shade300;
    final hintColor = isDark ? Colors.grey[500] : Colors.grey.shade400;

    // Responsive Logic: Use fixed values on Desktop to prevent "Cartoonishly Large" UI
    // On Mobile, use .h/.w for perfect scaling
    final bool isDesktop = Responsive.isDesktop(context);

    final double buttonHeight = isDesktop ? 50 : 50.h;
    final double spacingSmall = isDesktop ? 16 : 16.h;
    final double spacingLarge = isDesktop ? 40 : 40.h;
    final double horizontalPadding = isDesktop ? 0 : 20.w; // Container handles desktop padding

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: SingleChildScrollView(
            child: ResponsiveContainer(
              maxWidth: 450,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo Text
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
                      SizedBox(height: spacingLarge),

                      // Username
                      TextFormField(
                        controller: _username,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: "Username",
                          labelStyle: TextStyle(color: hintColor, fontSize: Responsive.fontSize(context, 14)),
                          filled: true,
                          fillColor: inputFillColor,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: isDesktop ? 16 : 16.w,
                              vertical: isDesktop ? 16 : 16.h
                          ),
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
                      SizedBox(height: spacingSmall),

                      // Email
                      TextFormField(
                        controller: _email,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: "Email",
                          labelStyle: TextStyle(color: hintColor, fontSize: Responsive.fontSize(context, 14)),
                          filled: true,
                          fillColor: inputFillColor,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: isDesktop ? 16 : 16.w,
                              vertical: isDesktop ? 16 : 16.h
                          ),
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
                      SizedBox(height: spacingSmall),

                      // Password
                      TextFormField(
                        controller: _password,
                        obscureText: true,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: "Password",
                          labelStyle: TextStyle(color: hintColor, fontSize: Responsive.fontSize(context, 14)),
                          filled: true,
                          fillColor: inputFillColor,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: isDesktop ? 16 : 16.w,
                              vertical: isDesktop ? 16 : 16.h
                          ),
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

                      // Create Account Button
                      ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size(double.infinity, buttonHeight),
                            backgroundColor: const Color(0xFF1A60FF),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(Responsive.radius(context, 12)),
                            ),
                          ),
                          child: Text(
                            "Create Account",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: Responsive.fontSize(context, 16),
                                fontWeight: FontWeight.bold
                            ),
                          )
                      ),
                      SizedBox(height: spacingSmall),

                      // Back to Login Link
                      TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          // Fix: Ensure standard padding on desktop so it doesn't look huge
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                                vertical: isDesktop ? 12 : 8.h,
                                horizontal: isDesktop ? 16 : 16.w
                            ),
                          ),
                          child: Text(
                            "Already Have an account? Log in",
                            style: TextStyle(
                                color: const Color(0xFF1A60FF),
                                fontSize: Responsive.fontSize(context, 14),
                                fontWeight: FontWeight.w600
                            ),
                          )
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