
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ตรวจสอบว่า import service ของคุณถูกต้อง
import 'package:liber_res/services/booking_service.dart';

class AddRoomPage extends StatefulWidget {
  const AddRoomPage({Key? key}) : super(key: key);

  @override
  _AddRoomPageState createState() => _AddRoomPageState();
}

class _AddRoomPageState extends State<AddRoomPage> {
  final _formKey = GlobalKey<FormState>();
  final _roomNameController = TextEditingController();
  final _capacityController = TextEditingController();
  final _equipmentController = TextEditingController();

  bool _isLoading = false;

  Future<void> _submitForm() async {
    // ตรวจสอบว่าฟอร์มถูกต้องหรือไม่
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      // แปลง String อุปกรณ์เป็น List
      // เช่น "TV, Projector" -> ["TV", "Projector"]
      List<String> equipmentList = _equipmentController.text
          .split(',') // แยกด้วยลูกน้ำ
          .map((e) => e.trim()) // ลบช่องว่างหน้า-หลัง
          .where((e) => e.isNotEmpty) // ไม่เอาค่าว่าง
          .toList();

      try {
        // เรียกใช้ฟังก์ชัน static ที่เราเตรียมไว้ใน BookingService
        await BookingService.addRoom(
          roomName: _roomNameController.text,
          capacity: int.parse(_capacityController.text),
          equipment: equipmentList,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เพิ่มห้องสำเร็จ!')),
        );
        Navigator.pop(context); // กลับไปหน้า Admin Home
      } catch (e) {
        setState(() => _isLoading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    // คืนค่า memory เมื่อปิดหน้านี้
    _roomNameController.dispose();
    _capacityController.dispose();
    _equipmentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('เพิ่มห้องใหม่'),
        backgroundColor: const Color(0xFF7A1F1F), // ใช้สีเดียวกับแอป
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // ช่องกรอกชื่อห้อง
              TextFormField(
                controller: _roomNameController,
                decoration: InputDecoration(labelText: 'ชื่อห้อง'),
                validator: (value) =>
                    value!.isEmpty ? 'กรุณาใส่ชื่อห้อง' : null,
              ),
              SizedBox(height: 16),
              // ช่องกรอกความจุ
              TextFormField(
                controller: _capacityController,
                decoration: InputDecoration(labelText: 'ความจุ (คน)'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) =>
                    value!.isEmpty ? 'กรุณาใส่ความจุ' : null,
              ),
              SizedBox(height: 16),
              // ช่องกรอกอุปกรณ์
              TextFormField(
                controller: _equipmentController,
                decoration: InputDecoration(
                  labelText: 'อุปกรณ์ (คั่นด้วยลูกน้ำ ,)',
                  hintText: 'เช่น Projector, Whiteboard, TV',
                ),
              ),
              SizedBox(height: 32),
              // ปุ่มบันทึก
              ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7A1F1F),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16)
                ),
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('บันทึกห้อง'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}