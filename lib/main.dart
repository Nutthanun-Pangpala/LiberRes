import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

// import 'pages/wrapper.dart'; // (อันเก่า)
import './splash_screen.dart'; // (อันใหม่)
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
  }
}
