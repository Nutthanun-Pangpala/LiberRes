import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// --------------------------------------------------------------------------
// 1. (View) หน้าหลักสำหรับ "ดู" ข่าวสารทั้งหมด
// --------------------------------------------------------------------------
class AdminNewsPage extends StatelessWidget {
  const AdminNewsPage({super.key});

  // ฟังก์ชันสำหรับลบ (มี Dialog ยืนยัน)
  Future<void> _confirmDeleteNews(
    BuildContext context,
    String newsId,
    String title,
  ) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('คุณแน่ใจหรือไม่ว่าต้องการลบข่าวสาร "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('ลบ', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        await FirebaseFirestore.instance
            .collection('news')
            .doc(newsId)
            .delete();
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('ลบข่าวสาร "$title" สำเร็จ')));
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาดในการลบ: $e')));
      }
    }
  }

  // ฟังก์ชันนำทางไปหน้า "แก้ไข"
  void _navigateToEditNews(BuildContext context, DocumentSnapshot newsDoc) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => EditNewsPage(newsDoc: newsDoc)),
    );
  }

  // ฟังก์ชันจัดรูปแบบวันที่
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    return DateFormat('dd MMM yyyy, HH:mm').format(timestamp.toDate());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการข่าวสาร (News)'),
        backgroundColor: const Color(0xFF7A1F1F),
        foregroundColor: Colors.white,
      ),
      // (Create) ปุ่ม + สำหรับ "เพิ่ม" ข่าวใหม่
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (context) => const AddNewsPage()));
        },
        backgroundColor: const Color(0xFF7A1F1F),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // (Read) ดึงข้อมูลจาก 'news' โดยเรียงจากใหม่ไปเก่า
        stream: FirebaseFirestore.instance
            .collection('news')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('ยังไม่มีข่าวสาร (กด + เพื่อเพิ่ม)'),
            );
          }

          final newsItems = snapshot.data!.docs;

          return ListView.builder(
            itemCount: newsItems.length,
            padding: const EdgeInsets.all(8),
            itemBuilder: (context, index) {
              final newsDoc = newsItems[index];
              final data = newsDoc.data() as Map<String, dynamic>;

              final title = data['title'] ?? 'N/A';
              final subtitle = data['subtitle'] ?? 'N/A';
              final timestamp = data['createdAt'] as Timestamp?;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.fromLTRB(16, 10, 8, 10),
                  title: Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('$subtitle\n${_formatTimestamp(timestamp)}'),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // (Update) ปุ่ม "แก้ไข"
                      IconButton(
                        icon: Icon(
                          Icons.edit_outlined,
                          color: Colors.blue[700],
                        ),
                        tooltip: 'แก้ไข',
                        onPressed: () => _navigateToEditNews(context, newsDoc),
                      ),
                      // (Delete) ปุ่ม "ลบ"
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: Colors.red[700],
                        ),
                        tooltip: 'ลบ',
                        onPressed: () =>
                            _confirmDeleteNews(context, newsDoc.id, title),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// --------------------------------------------------------------------------
// 2. (Create) หน้าสำหรับ "เพิ่ม" ข่าวสาร
// (นี่คือ _NewsPublisher เดิม ที่ย้ายมาเป็นหน้าเต็ม)
// --------------------------------------------------------------------------
class AddNewsPage extends StatefulWidget {
  const AddNewsPage({super.key});
  @override
  State<AddNewsPage> createState() => _AddNewsPageState();
}

class _AddNewsPageState extends State<AddNewsPage> {
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  bool _isLoading = false;

  Future<void> _publishNews() async {
    final title = _titleController.text.trim();
    final subtitle = _subtitleController.text.trim();

    if (title.isEmpty || subtitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('กรุณากรอกทั้ง Title และ Subtitle')),
      );
      return;
    }
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('news').add({
        'title': title,
        'subtitle': subtitle,
        'published': "true",
        'createdAt': FieldValue.serverTimestamp(),
        'byAdminName': user?.displayName ?? 'Admin',
        'byAdminId': user?.uid ?? 'unknown',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ประกาศข่าวสารสำเร็จ!')));
      Navigator.pop(context); // 👈 กลับไปหน้า List
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เพิ่มข่าวสารใหม่'),
        backgroundColor: const Color(0xFF7A1F1F),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'หัวข้อ (Title)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 1,
            ),
            SizedBox(height: 16),
            TextField(
              controller: _subtitleController,
              decoration: InputDecoration(
                labelText: 'เนื้อหาย่อ (Subtitle)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 3,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              icon: Icon(Icons.campaign_outlined),
              onPressed: _isLoading ? null : _publishNews,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF7A1F1F),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              label: _isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text('ประกาศข่าว (Publish)'),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------
// 3. (Update) หน้าสำหรับ "แก้ไข" ข่าวสาร
// (คล้ายกับ EditRoomPage)
// --------------------------------------------------------------------------
class EditNewsPage extends StatefulWidget {
  final DocumentSnapshot newsDoc;
  const EditNewsPage({Key? key, required this.newsDoc}) : super(key: key);
  @override
  State<EditNewsPage> createState() => _EditNewsPageState();
}

class _EditNewsPageState extends State<EditNewsPage> {
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // โหลดข้อมูลเดิมมาใส่ฟอร์ม
    final data = widget.newsDoc.data() as Map<String, dynamic>;
    _titleController.text = data['title'] ?? '';
    _subtitleController.text = data['subtitle'] ?? '';
  }

  Future<void> _updateNews() async {
    final title = _titleController.text.trim();
    final subtitle = _subtitleController.text.trim();

    if (title.isEmpty || subtitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('กรุณากรอกทั้ง Title และ Subtitle')),
      );
      return;
    }
    setState(() => _isLoading = true);

    try {
      // ใช้ .update() ที่ doc ID เดิม
      await FirebaseFirestore.instance
          .collection('news')
          .doc(widget.newsDoc.id)
          .update({
            'title': title,
            'subtitle': subtitle,
            // (ไม่จำเป็นต้องอัปเดต createdAt)
          });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('อัปเดตข่าวสารสำเร็จ!')));
      Navigator.pop(context); // 👈 กลับไปหน้า List
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('แก้ไขข่าวสาร'),
        backgroundColor: const Color(0xFF7A1F1F),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'หัวข้อ (Title)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 1,
            ),
            SizedBox(height: 16),
            TextField(
              controller: _subtitleController,
              decoration: InputDecoration(
                labelText: 'เนื้อหาย่อ (Subtitle)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 3,
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _updateNews,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF7A1F1F),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text('บันทึกการแก้ไข'),
            ),
          ],
        ),
      ),
    );
  }
}
