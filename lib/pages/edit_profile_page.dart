import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import './home_page.dart'; // To access the maroon color

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  // --- Controllers for the editable field (Display Name) ---
  final TextEditingController _displayNameController = TextEditingController();

  bool _isLoading = false;

  // Method to simulate photo picking/upload, since actual file picking is complex
  Future<void> _handlePhotoUpload() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('กำลังเปิดตัวเลือกไฟล์ (File Picker) เพื่อแนบรูป...'),
        duration: Duration(seconds: 2),
      ),
    );
    // In a real application, this is where you would use image_picker
    // and Firebase Storage to upload the image and get the photoURL.
    // For now, it only shows a message.
  }

  // Function to save data to Firebase Auth and Firestore (for consistency)
  Future<void> _saveProfile(String uid) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final newDisplayName = _displayNameController.text.trim();

    if (newDisplayName.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ชื่อที่แสดงต้องไม่ว่างเปล่า')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. อัปเดต Display Name ใน Firebase Authentication
      await user.updateProfile(displayName: newDisplayName);

      // 2. อัปเดต Firestore เพื่อให้ข้อมูล studentId/role/status สอดคล้องกับ displayName ที่อัปเดต
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'displayName': newDisplayName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('บันทึกโปรไฟล์สำเร็จ!')));
      Navigator.pop(context); // Go back to Settings page
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Method to set initial values for controllers from fetched data
  void _initializeControllers(
    String displayName,
    String photoUrl,
    String studentId,
    String email,
  ) {
    // Set Display Name (Editable Field)
    if (_displayNameController.text.isEmpty) {
      _displayNameController.text = displayName;
    }
    // We don't need controllers for the rest as they are read-only and passed to fields
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('ผู้ใช้ไม่ได้เข้าสู่ระบบ')),
      );
    }

    // StreamBuilder to fetch profile data in real-time
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        // 1. Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('แก้ไขโปรไฟล์'),
              backgroundColor: HomePage.maroon,
              foregroundColor: Colors.white,
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        // 2. Error handling
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('แก้ไขโปรไฟล์'),
              backgroundColor: HomePage.maroon,
              foregroundColor: Colors.white,
            ),
            body: Center(
              child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: ${snapshot.error}'),
            ),
          );
        }

        // 3. Data extraction and initialization
        final data = snapshot.data?.data();

        // Data from Auth (Primary source for displayName/email)
        final displayName = user.displayName ?? '';
        final authEmail = user.email ?? 'No Email';
        final photoUrl = user.photoURL ?? '';

        // Data from Firestore (Secondary source for status/role/studentId)
        final studentId = data?['studentId'] as String? ?? '-';
        final role = data?['role'] as String? ?? '-';
        final status = data?['status'] as String? ?? '-';

        // Initialize editable field controller
        _initializeControllers(displayName, photoUrl, studentId, authEmail);

        return Scaffold(
          appBar: AppBar(
            title: const Text('แก้ไขโปรไฟล์'),
            backgroundColor: HomePage.maroon,
            foregroundColor: Colors.white,
            elevation: 1,
          ),
          backgroundColor: HomePage.bg,
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // ----------------- Profile Image & Upload Button -----------------
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: HomePage.maroon.withOpacity(0.1),
                      // Display image from Firebase Auth
                      backgroundImage: photoUrl.isNotEmpty
                          ? NetworkImage(photoUrl)
                          : null,
                      child: photoUrl.isEmpty
                          ? Icon(Icons.person, size: 50, color: HomePage.maroon)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _handlePhotoUpload, // Call upload handler
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: HomePage.maroon,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // ----------------- Input Fields -----------------
              const Text(
                'ข้อมูลบัญชี',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 10),

              // Field 1: Display Name (Editable)
              _ProfileInputField(
                label: 'ชื่อที่แสดง (Display Name)',
                controller: _displayNameController,
                isEditable: true,
                keyboardType: TextInputType.text,
              ),

              // Field 2: Email (Read-only)
              _ProfileInputField(
                label: 'อีเมล',
                initialValue: authEmail, // ใช้ initialValue สำหรับค่า Read-Only
                isEditable: false,
                keyboardType: TextInputType.emailAddress,
              ),

              // Field 3: Student ID (Read-only)
              _ProfileInputField(
                label: 'รหัสนักศึกษา',
                initialValue: studentId,
                isEditable: false,
                keyboardType: TextInputType.text,
              ),

              // Field 4: Role (Read-only)
              _ProfileInputField(
                label: 'บทบาท',
                initialValue: role,
                isEditable: false,
                keyboardType: TextInputType.text,
              ),

              // Field 5: Status (Read-only)
              _ProfileInputField(
                label: 'สถานะ',
                initialValue: status,
                isEditable: false,
                keyboardType: TextInputType.text,
              ),

              const SizedBox(height: 30),

              // ----------------- Save Button -----------------
              ElevatedButton(
                // Disable button during loading
                onPressed: _isLoading ? null : () => _saveProfile(user.uid),
                style: ElevatedButton.styleFrom(
                  backgroundColor: HomePage.maroon,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: HomePage.maroon.withOpacity(0.5),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'บันทึก',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Widget for styled Input Field (adjusted for mix of Controller and initialValue)
class _ProfileInputField extends StatelessWidget {
  final String label;
  final TextEditingController? controller; // Optional controller
  final String? initialValue; // Optional initial value (for read-only)
  final bool isEditable;
  final TextInputType keyboardType;

  const _ProfileInputField({
    super.key,
    required this.label,
    this.controller,
    this.initialValue,
    required this.isEditable,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        // Use controller if provided, otherwise create one for read-only fields
        controller: controller ?? TextEditingController(text: initialValue),
        readOnly: !isEditable, // Use readOnly for clearer UX
        enabled: isEditable,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isEditable ? HomePage.maroon : Colors.black54,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isEditable ? HomePage.maroon : Colors.grey.shade300,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isEditable
                  ? HomePage.maroon.withOpacity(0.5)
                  : Colors.grey.shade300,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: HomePage.maroon, width: 2),
          ),
          fillColor: isEditable ? Colors.white : Colors.grey.shade100,
          filled: true,
          suffixIcon: isEditable
              ? const Icon(Icons.edit_outlined, size: 18)
              : null,
        ),
      ),
    );
  }
}
