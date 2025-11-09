import 'dart:async';

import 'package:flutter/material.dart';

import './pages/home_page.dart'; // (นำเข้า HomePage เพื่อใช้สี)
import './pages/wrapper.dart'; // (นำเข้า Wrapper)

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _opacity = 0.0;

  @override
  void initState() {
    super.initState();

    // 1. เริ่ม Animation (Fade-in)
    // (ใช้ addPostFrameCallback เพื่อให้แน่ใจว่า UI พร้อมก่อนเริ่ม animation)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _opacity = 1.0);
      }
    });

    // 2. ตั้งเวลา 2 วินาที แล้วไปหน้า Wrapper
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const Wrapper()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomePage.bg, // ใช้สีพื้นหลังเดียวกับ Home
      body: Center(
        child: AnimatedOpacity(
          opacity: _opacity,
          duration: const Duration(milliseconds: 1200), // 1.2 วินาที
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. ไอคอนโลโก้
              Icon(
                Icons.menu_book_rounded,
                size: 80,
                color: HomePage.maroon, // ใช้สีหลัก
              ),
              const SizedBox(height: 16),

              // 2. ชื่อแอป
              const Text(
                'LiberRes',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: HomePage.maroon,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
