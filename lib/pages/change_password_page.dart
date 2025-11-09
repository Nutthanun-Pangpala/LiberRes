// change_password_page.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import './home_page.dart'; // To access the maroon color

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Function to handle the password change logic
  Future<void> _handleChangePassword() async {
    if (!_formKey.currentState!.validate()) {
      return; // Stop if form is invalid
    }

    setState(() {
      _isLoading = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;

    if (user == null || user.email == null) {
      _showErrorSnackBar('ไม่พบข้อมูลผู้ใช้ กรุณาล็อกอินใหม่');
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Re-authenticate the user with their current password
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // 2. If re-authentication is successful, update the password
      await user.updatePassword(newPassword);

      // 3. Success
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('เปลี่ยนรหัสผ่านสำเร็จ!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context); // Go back to Settings
    } on FirebaseAuthException catch (e) {
      // Handle specific errors
      String errorMessage = 'เกิดข้อผิดพลาด: ${e.message}';
      if (e.code == 'wrong-password') {
        errorMessage = 'รหัสผ่านปัจจุบันไม่ถูกต้อง';
      } else if (e.code == 'weak-password') {
        errorMessage = 'รหัสผ่านใหม่อ่อนแอเกินไป (ต้อง 6 ตัวอักษรขึ้นไป)';
      } else if (e.code == 'requires-recent-login') {
        errorMessage =
            'กรุณาล็อกเอาท์และล็อกอินใหม่อีกครั้งเพื่อเปลี่ยนรหัสผ่าน';
      }
      _showErrorSnackBar(errorMessage);
    } catch (e) {
      // Handle other errors
      _showErrorSnackBar('เกิดข้อผิดพลาดที่ไม่รู้จัก: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomePage.bg,
      appBar: AppBar(
        title: const Text('เปลี่ยนรหัสผ่าน'),
        backgroundColor: HomePage.maroon,
        foregroundColor: Colors.white,
        elevation: 1,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'เพื่อความปลอดภัย กรุณายืนยันรหัสผ่านปัจจุบันของคุณก่อนตั้งรหัสผ่านใหม่',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 24),

            // --- Current Password ---
            TextFormField(
              controller: _currentPasswordController,
              obscureText: _obscureCurrent,
              decoration: _inputDecoration(
                'รหัสผ่านปัจจุบัน',
                Icons.lock_outline,
                IconButton(
                  icon: Icon(
                    _obscureCurrent ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _obscureCurrent = !_obscureCurrent),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'กรุณากรอกรหัสผ่านปัจจุบัน';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // --- New Password ---
            TextFormField(
              controller: _newPasswordController,
              obscureText: _obscureNew,
              decoration: _inputDecoration(
                'รหัสผ่านใหม่',
                Icons.lock,
                IconButton(
                  icon: Icon(
                    _obscureNew ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'กรุณากรอกรหัสผ่านใหม่';
                }
                if (value.length < 6) {
                  return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // --- Confirm New Password ---
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirm,
              decoration: _inputDecoration(
                'ยืนยันรหัสผ่านใหม่',
                Icons.lock_clock_outlined,
                IconButton(
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'กรุณายืนยันรหัสผ่านใหม่';
                }
                if (value != _newPasswordController.text) {
                  return 'รหัสผ่านใหม่ไม่ตรงกัน';
                }
                return null;
              },
            ),
            const SizedBox(height: 30),

            // --- Save Button ---
            ElevatedButton(
              onPressed: _isLoading ? null : _handleChangePassword,
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
                      'บันทึกรหัสผ่านใหม่',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method for input decoration
  InputDecoration _inputDecoration(
    String label,
    IconData icon,
    Widget suffixIcon,
  ) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.black54),
      prefixIcon: Icon(icon, color: HomePage.maroon, size: 20),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: HomePage.maroon, width: 2),
      ),
      fillColor: Colors.white,
      filled: true,
    );
  }
}
