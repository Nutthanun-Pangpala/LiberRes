import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
// [แก้ไข 1] import ที่ถูกต้องคือ 'package:intl' (มี :)
import 'package:intl/date_symbol_data_local.dart';

// import 'pages/wrapper.dart'; // (อันเก่า)
import './splash_screen.dart'; // (อันใหม่)
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // [แก้ไข 2] ย้ายโค้ดมาไว้ที่นี่ครับ! (ก่อน runApp)
  await initializeDateFormatting('th_TH', null);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LiberRes Login',
      theme: ThemeData(primarySwatch: Colors.red),

      // ‼️ แก้ไข: เปลี่ยน home จาก Wrapper เป็น SplashScreen
      home: const SplashScreen(),
    );
    // [แก้ไข 3] ลบโค้ดบรรทัดนี้ออกจากที่นี่
  }
}
