import 'dart:async';

import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';

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
    // TODO: implement initState
    super.initState();
    timer = Timer(Duration(seconds: 3), () {
      navigateToCreateAccount();
    },);
  }
  void navigateToCreateAccount(){
    if(mounted){
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) =>SignInPage() ,));
    }
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LottieBuilder.asset("asset/lotties/Chat Messenger/animations/12345.json"),
            SizedBox(height: 15.h,),
            AnimatedTextKit(
              animatedTexts: [
                TypewriterAnimatedText(
                  'Chatty',
                  textStyle: const TextStyle(
                    fontSize: 32.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    decoration:TextDecoration.none
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
