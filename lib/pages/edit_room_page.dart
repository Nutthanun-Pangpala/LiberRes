import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EditRoomPage extends StatefulWidget {
  // เราจะรับ 'roomDoc' (ข้อมูลห้องเดิม) เข้ามา
  final DocumentSnapshot roomDoc;

  const EditRoomPage({Key? key, required this.roomDoc}) : super(key: key);

  @override
  _EditRoomPageState createState() => _EditRoomPageState();
}

class _EditRoomPageState extends State<EditRoomPage> {
  final _formKey = GlobalKey<FormState>();
  final _roomNameController = TextEditingController();
  final _capacityController = TextEditingController();
  final _equipmentController = TextEditingController();

  bool _isLoading = false;
  final Color primaryColor = const Color(0xFF7A1F1F);

  @override
  void initState() {
    super.initState();
    // เมื่อหน้าโหลด, ดึงข้อมูลเดิมจาก 'roomDoc' มาใส่ใน Controller
    _loadExistingData();
  }

  void _loadExistingData() {
    final data = widget.roomDoc.data() as Map<String, dynamic>;

    _roomNameController.text = data['roomName'] ?? '';
    _capacityController.text = (data['capacity'] ?? 0).toString();

    // แปลง List equipment กลับเป็น String (เช่น ["TV", "Mic"] -> "TV, Mic")
    final List<String> equipmentList = List<String>.from(
      data['equipment'] ?? [],
    );
    _equipmentController.text = equipmentList.join(', ');
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final int? capacity = int.tryParse(_capacityController.text);
    if (capacity == null) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ค่าความจุไม่ถูกต้อง')));
      return;
    }

    List<String> equipmentList = _equipmentController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    try {
      // [สำคัญ] เราใช้ .update() แทน .add()
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomDoc.id) // 👈 ระบุ ID ของห้องที่จะอัปเดต
          .update({
            'roomName': _roomNameController.text,
            'capacity': capacity,
            'equipment': equipmentList,
          });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('อัปเดตห้องสำเร็จ!')));
      Navigator.pop(context); // กลับไปหน้า Admin Rooms
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    }
  }

  @override
  void dispose() {
    _roomNameController.dispose();
    _capacityController.dispose();
    _equipmentController.dispose();
    super.dispose();
  }

  // (ยก UI/UX ที่เราทำไว้ใน AddRoomPage มาใช้)
  InputDecoration _buildInputDecoration(
    String label,
    IconData icon, {
    String? hint,
    String? helper,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      prefixIcon: Icon(icon, color: primaryColor.withOpacity(0.8)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: Colors.grey.shade400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'แก้ไขห้อง: ${widget.roomDoc['roomName']}',
        ), // 👈 เปลี่ยน Title
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _roomNameController,
                  decoration: _buildInputDecoration(
                    'ชื่อห้อง',
                    Icons.meeting_room_outlined,
                  ),
                  validator: (value) =>
                      value!.isEmpty ? 'กรุณาใส่ชื่อห้อง' : null,
                ),
                SizedBox(height: 20),
                TextFormField(
                  controller: _capacityController,
                  decoration: _buildInputDecoration(
                    'ความจุ (คน)',
                    Icons.people_outline,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) =>
                      value!.isEmpty ? 'กรุณาใส่ความจุ' : null,
                ),
                SizedBox(height: 20),
                TextFormField(
                  controller: _equipmentController,
                  decoration: _buildInputDecoration(
                    'อุปกรณ์',
                    Icons.devices_other_outlined,
                    hint: 'เช่น Projector, Whiteboard, TV',
                    helper: 'คั่นแต่ละรายการด้วยลูกน้ำ ( , )',
                  ),
                ),
                SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        )
                      : Text(
                          'บันทึกการแก้ไข',
                          style: TextStyle(fontSize: 16),
                        ), // 👈 เปลี่ยน Text
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
