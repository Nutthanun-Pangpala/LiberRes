import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ต้องมั่นใจว่า path นี้ถูกต้อง
import 'admin_home_page.dart'; 
import 'home_page.dart';
import 'login_page.dart';

class Wrapper extends StatelessWidget {
  const Wrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Stream: ติดตามสถานะการล็อกอินของ Firebase Auth
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // แสดง Loading Screen ขณะรอสถานะเริ่มต้น
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          final u = snapshot.data!;
          
          // 2. FutureBuilder: ดึงข้อมูล User Document เพื่อตรวจสอบ Role
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(u.uid)
                .get(),
            builder: (context, docSnapshot) {
              if (docSnapshot.connectionState == ConnectionState.waiting) {
                // แสดง Loading ขณะรอข้อมูล Role จาก Firestore
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              
              if (docSnapshot.hasError || !docSnapshot.hasData || !docSnapshot.data!.exists) {
                // หากดึงข้อมูลไม่ได้, ให้ถือว่าเป็นผู้ใช้ทั่วไป (student)
                // หรืออาจจะส่งไปยังหน้า Error แล้วบังคับ Log out
                debugPrint('Error or Missing User Doc. Defaulting to HomePage.');
                return const HomePage();
              }
              
              // 3. Check Role และส่งไปยังหน้า Dashboard ที่ถูกต้อง
              final role = docSnapshot.data?.get('role') ?? 'student';

              if (role == 'admin') {
                return const AdminHomePage(); // Admin Dashboard
              } else {
                return const HomePage(); // User Dashboard (Home Page)
              }
            },
          );
        } else {
          // ผู้ใช้ไม่ได้ล็อกอิน
          return const LoginPage();
        }
      },
    );
  }
}