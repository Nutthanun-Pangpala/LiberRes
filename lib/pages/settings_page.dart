// settings_page.dart

import 'package:flutter/material.dart';

import './change_password_page.dart';
// นำเข้าหน้าที่สร้างใหม่
import './edit_profile_page.dart';
// ต้องนำเข้า home_page เพื่อใช้สี maroon
import './home_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // ใช้องค์ประกอบที่ปรับให้สวยงามและเป็นระเบียบ
    return Scaffold(
      backgroundColor: HomePage.bg, // ใช้สีพื้นหลังของ HomePage
      appBar: AppBar(
        title: const Text('การตั้งค่า'),
        backgroundColor: HomePage.maroon,
        foregroundColor: Colors.white,
        elevation: 0, // ลบเงา AppBar เพื่อให้ดูทันสมัย
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        children: [
          // ----------------- ส่วนบัญชี (Group 1) -----------------
          _SettingsGroup(
            title: 'บัญชีผู้ใช้ (Account)',
            children: [
              _SettingsTile(
                icon: Icons.person_outline,
                title: 'แก้ไขโปรไฟล์',
                subtitle: 'อัปเดตข้อมูลส่วนตัวและรูปภาพ',
                routePath: '/edit-profile', // กำหนดเส้นทาง
              ),
              const Divider(height: 1, indent: 20, endIndent: 20),
              _SettingsTile(
                icon: Icons.lock_outline,
                title: 'เปลี่ยนรหัสผ่าน',
                subtitle: 'รักษาบัญชีของคุณให้ปลอดภัยอยู่เสมอ',
                routePath: '/change-password', // กำหนดเส้นทาง
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ----------------- ส่วนแอปพลิเคชัน (Group 2) -----------------
          _SettingsGroup(
            title: 'แอปพลิเคชัน (App)',
            children: [
              _SettingsTile(
                icon: Icons.notifications_none,
                title: 'การแจ้งเตือน',
                subtitle: 'ตั้งค่าการแจ้งเตือนการจองและประกาศ',
                routePath: '/notifications',
              ),
              const Divider(height: 1, indent: 20, endIndent: 20),
              _SettingsTile(
                icon: Icons.info_outline,
                title: 'เกี่ยวกับ LiberRes',
                subtitle: 'ข้อมูลเวอร์ชันและข้อกำหนดการใช้งาน',
                isAbout: true, // ตั้งค่าให้แสดง AboutDialog แทนการนำทาง
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Custom Widget สำหรับจัดกลุ่มการตั้งค่า
class _SettingsGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SettingsGroup({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12, left: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black54,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: HomePage.maroon.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          // ใช้ ClipRRect เพื่อให้ InkWell โค้งตาม Container
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}

// Custom Widget สำหรับแต่ละรายการตั้งค่า
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? routePath;
  final bool isAbout;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.routePath,
    this.isAbout = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent, // ทำให้โปร่งแสงเพื่อใช้สีของ Container แม่
      child: InkWell(
        // ไม่ต้องกำหนด borderRadius ที่นี่ เพราะ ClipRRect จัดการแล้ว
        onTap: () {
          if (isAbout) {
            // 1. แสดง About Dialog
            showAboutDialog(
              context: context,
              applicationName: 'LiberRes',
              applicationVersion: '1.0.0',
              children: const [Text('แอปพลิเคชันจองพื้นที่ห้องสมุด')],
            );
          } else if (routePath == '/edit-profile') {
            // 2. ไปหน้า Edit Profile
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const EditProfilePage()));
          } else if (routePath == '/change-password') {
            // 3. ไปหน้า Change Password
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
            );
          } else if (routePath != null) {
            // 4. แสดง Placeholder
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('ไปหน้า $title (เร็วๆ นี้)')),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              Icon(
                icon,
                color: HomePage.maroon,
                size: 24,
              ), // ใช้สี Maroon เป็นสี Icon
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}
