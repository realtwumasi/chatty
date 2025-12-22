import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:chatty/home/components/Floating_btn.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        title: AnimatedTextKit(
          animatedTexts: [
            TypewriterAnimatedText(
              'Chatty',
              textStyle: const TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
              ),
              speed: const Duration(milliseconds: 350),
            ),
          ],
          totalRepeatCount: 1,
        ),
      ),
      endDrawer: Drawer(),
      body: SingleChildScrollView(
        child: Column(

        ),
      ),

      floatingActionButton:FloatingBtn(),
    );
  }
}
