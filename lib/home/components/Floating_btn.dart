import 'package:flutter/material.dart';

class FloatingBtn extends StatefulWidget {
  const FloatingBtn({super.key});

  @override
  State<FloatingBtn> createState() => _FloatingBtnState();
}

class _FloatingBtnState extends State<FloatingBtn> {
  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      elevation: 0,
      backgroundColor: Color(0xFF1A60FF),
      onPressed: () {

    },
      child: Icon(Icons.message,color: Colors.white,),
    );
  }
}
