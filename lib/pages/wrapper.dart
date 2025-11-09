import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          // แสดง Loading Screen ขณะรอสถานะเริ่มต้น
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (authSnapshot.hasData) {
          // ผู้ใช้ล็อกอินแล้ว
          final u = authSnapshot.data!;

          // 2. ‼️ แก้ไข: เปลี่ยน FutureBuilder เป็น StreamBuilder ‼️
          //    ใช้ .snapshots() แทน .get() เพื่อฟังการเปลี่ยนแปลง Role แบบ Real-time
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(u.uid)
                .snapshots(), // ใช้ .snapshots()
            builder: (context, docSnapshot) {
              // 3. ปรับปรุงการจัดการ State
              if (docSnapshot.connectionState == ConnectionState.waiting) {
                // แสดง Loading ขณะรอข้อมูล Role จาก Firestore (จะเกิดขึ้นแค่ครั้งแรก)
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (docSnapshot.hasError) {
                // ถ้าดึงข้อมูล Role ไม่ได้ ให้แสดง Error หรือไปหน้าหลัก
                debugPrint('Error loading user role: ${docSnapshot.error}');
                return const HomePage(); // ไปหน้าหลัก (ปลอดภัยกว่า)
              }

              if (!docSnapshot.hasData || !docSnapshot.data!.exists) {
                // (Race Condition) หาก User เพิ่งสมัครและยังไม่มี Document
                // ให้ไปหน้าหลักก่อน StreamBuilder จะอัปเดตอัตโนมัติเมื่อ Document ถูกสร้าง
                debugPrint(
                  'User document does not exist yet. Defaulting to HomePage.',
                );
                return const HomePage();
              }

              // 4. Check Role และส่งไปยังหน้า Dashboard ที่ถูกต้อง
              // (หาก Role ถูกเปลี่ยนใน Firestore, StreamBuilder จะทำงานใหม่และสลับหน้าให้อัตโนมัติ)
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
