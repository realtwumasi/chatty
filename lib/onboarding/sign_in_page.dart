import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:chatty/onboarding/create_account.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final GlobalKey _formkey = GlobalKey();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: EdgeInsets.only(left: 20,right: 20),
            child: Form(
              key: _formkey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,

                children: [
                  //logo text(chatty)
                  AnimatedTextKit(
                    animatedTexts: [
                      TypewriterAnimatedText(
                        'Chatty',
                        textStyle: const TextStyle(
                          fontSize: 32.0,
                          fontWeight: FontWeight.bold,
                        ),
                        speed: const Duration(milliseconds: 350),
                      ),
                    ],
                    totalRepeatCount: 1,
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    "Welcome back",
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: 16.sp,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  SizedBox(height: 40.h),
                  //username
                  TextFormField(
                    controller: _username,
                    decoration: InputDecoration(
                      hint: Text("Username"),
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14.sp),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: const BorderSide(color: Colors.blue, width: 1.5),
                      ),
                    ),
                  ),
                  SizedBox(height: 15.h),
                  //password
                  TextFormField(
                    controller: _password,
                    decoration: InputDecoration(
                      hint: Text("Password"),
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14.sp),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: const BorderSide(color: Colors.blue, width: 1.5),
                      ),
                    ),
                  ),
                  SizedBox(height: 15.h,),
                  //login button
                  ElevatedButton(onPressed: () {

                  }, style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50.h),
                    backgroundColor: const Color(0xFF1A60FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),child: Text("Log in",style: TextStyle(
                    color: Colors.white
                  ),)),
                  SizedBox(height: 15.h,),
                  //create account
                  TextButton(onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder:  (context) => CreateAccount(),));
                  }, child: Text("Create Account",style: TextStyle(
                    color:const Color(0xFF1A60FF)
                  ),))
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
