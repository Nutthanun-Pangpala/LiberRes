import 'package:flutter/material.dart';

// ต้องนำเข้าไฟล์ home_page เพื่อใช้สี maroon
import './home_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('การตั้งค่า'),
        // ใช้ HomePage.maroon (ตัวแปร public ที่แก้ไข)
        backgroundColor: HomePage.maroon,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // ----------------- ส่วนบัญชี -----------------
          const Text(
            'บัญชีผู้ใช้',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('แก้ไขโปรไฟล์'),
            subtitle: const Text('อัปเดตชื่อ, รหัสนักศึกษา, และรูปภาพ'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ไปหน้าแก้ไขโปรไฟล์ (เร็วๆ นี้)')),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('เปลี่ยนรหัสผ่าน'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('ไปหน้าเปลี่ยนรหัสผ่าน (เร็วๆ นี้)'),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // ----------------- ส่วนแอปพลิเคชัน -----------------
          const Text(
            'แอปพลิเคชัน',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.notifications_none),
            title: const Text('การแจ้งเตือน'),
            subtitle: const Text('ตั้งค่าการแจ้งเตือนการจอง'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('ไปหน้าตั้งค่าการแจ้งเตือน (เร็วๆ นี้)'),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('เกี่ยวกับ LiberRes'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'LiberRes',
                applicationVersion: '1.0.0',
                children: [const Text('แอปพลิเคชันจองพื้นที่ห้องสมุด')],
              );
            },
          ),
        ],
      ),
    );
  }
}
