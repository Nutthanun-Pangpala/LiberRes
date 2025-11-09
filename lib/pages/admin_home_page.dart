import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:liber_res/pages/addroom_page.dart';
// [เพิ่ม] 1. Import หน้า News ที่เราจะสร้างใหม่
import 'package:liber_res/pages/admin_news_page.dart';
import 'package:liber_res/pages/edit_room_page.dart';
import 'package:liber_res/services/booking_service.dart';

// --------------------------------------------------------------------------
// ADMIN FEATURE PAGES
// --------------------------------------------------------------------------

// --- 1. จัดการห้อง (Admin: Room Management) ---
// (คลาส AdminRoomsPage ไม่เปลี่ยนแปลง)
class AdminRoomsPage extends StatelessWidget {
  const AdminRoomsPage({super.key});

  Future<void> _confirmDeleteRoom(
    BuildContext context,
    String roomId,
    String roomName,
  ) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('คุณแน่ใจหรือไม่ว่าต้องการลบห้อง "$roomName"?'),
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
            .collection('rooms')
            .doc(roomId)
            .delete();
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('ลบห้อง $roomName สำเร็จ')));
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาดในการลบ: $e')));
      }
    }
  }

  void _navigateToEditRoom(BuildContext context, DocumentSnapshot roomDoc) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => EditRoomPage(roomDoc: roomDoc)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการห้อง (Rooms)'),
        backgroundColor: const Color(0xFF7A1F1F),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: Icon(
              Icons.add_circle_outline,
              color: Color(0xFF7A1F1F),
              size: 30,
            ),
            title: Text(
              'เพิ่มห้องใหม่',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('สร้างห้องสำหรับให้จอง'),
            trailing: Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AddRoomPage()),
              );
            },
          ),
          const Divider(height: 24),
          const Text(
            'รายการห้องทั้งหมด',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('rooms')
                .orderBy('roomName')
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
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text('ยังไม่มีห้องในระบบ (กด + เพื่อเพิ่ม)'),
                  ),
                );
              }

              final rooms = snapshot.data!.docs;

              return ListView.builder(
                itemCount: rooms.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final roomDoc = rooms[index];
                  final roomData = roomDoc.data() as Map<String, dynamic>;
                  final roomName = roomData['roomName'] ?? 'N/A';
                  final capacity = roomData['capacity'] ?? 0;
                  final List<String> equipment = List<String>.from(
                    roomData['equipment'] ?? [],
                  );

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.fromLTRB(16, 10, 8, 10),
                      leading: CircleAvatar(
                        backgroundColor: Color(0xFF7A1F1F).withOpacity(0.1),
                        child: Text(
                          '$capacity',
                          style: TextStyle(
                            color: Color(0xFF7A1F1F),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        roomName,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        equipment.isEmpty
                            ? 'ไม่มีอุปกรณ์'
                            : 'อุปกรณ์: ${equipment.join(', ')}',
                      ),
                      isThreeLine: equipment.isNotEmpty,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.edit_outlined,
                              color: Colors.blue[700],
                            ),
                            tooltip: 'แก้ไข',
                            onPressed: () =>
                                _navigateToEditRoom(context, roomDoc),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: Colors.red[700],
                            ),
                            tooltip: 'ลบ',
                            onPressed: () => _confirmDeleteRoom(
                              context,
                              roomDoc.id,
                              roomName,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

// --- 2. จัดการวันหยุด (Admin: Holiday Management) ---
// (คลาส AdminHolidaysPage ไม่เปลี่ยนแปลง)
class AdminHolidaysPage extends StatefulWidget {
  const AdminHolidaysPage({super.key});
  @override
  State<AdminHolidaysPage> createState() => _AdminHolidaysPageState();
}

class _AdminHolidaysPageState extends State<AdminHolidaysPage> {
  final CollectionReference _holidaysRef = FirebaseFirestore.instance
      .collection('holidays');
  bool _isSyncing = false;

  Future<void> _syncHolidays() async {
    setState(() => _isSyncing = true);
    try {
      int year = DateTime.now().year;
      await BookingService.syncHolidaysFromAPI(year);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ซิงค์วันหยุดราชการไทยปี $year สำเร็จ!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    }
    setState(() => _isSyncing = false);
  }

  Future<void> _addHoliday() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (pickedDate == null) return;
    final String? reason = await _showReasonDialog();
    if (reason == null || reason.isEmpty) return;
    final String dateId = DateFormat('yyyy-MM-dd').format(pickedDate);
    await _holidaysRef.doc(dateId).set({
      'description': reason,
      'date': Timestamp.fromDate(pickedDate),
      'isManual': true,
    });
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('เพิ่มวันหยุด $dateId แล้ว')));
  }

  Future<String?> _showReasonDialog() {
    final TextEditingController reasonController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('เพิ่มเหตุผล (วันหยุด)'),
          content: TextField(
            controller: reasonController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'เช่น วันหยุดพิเศษบริษัท',
            ),
          ),
          actions: [
            TextButton(
              child: const Text('ยกเลิก'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('บันทึก'),
              onPressed: () => Navigator.of(context).pop(reasonController.text),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteHoliday(String dateId) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('คุณต้องการลบวันหยุด $dateId ออกจากระบบหรือไม่?'),
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
      await _holidaysRef.doc(dateId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ลบวันหยุด $dateId แล้ว')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการวันหยุด (Holidays)'),
        backgroundColor: const Color(0xFF7A1F1F),
        foregroundColor: Colors.white,
        actions: [
          if (_isSyncing)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.sync),
              tooltip: 'ดึงวันหยุดราชการไทย (ปีปัจจุบัน)',
              onPressed: _syncHolidays,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addHoliday,
        backgroundColor: const Color(0xFF7A1F1F),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _holidaysRef.orderBy('date').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          final holidays = snapshot.data!.docs;
          if (holidays.isEmpty)
            return const Center(child: Text('ไม่มีวันหยุดที่กำหนดไว้'));
          return ListView.builder(
            itemCount: holidays.length,
            itemBuilder: (context, index) {
              final doc = holidays[index];
              final data = doc.data() as Map<String, dynamic>;
              final dateId = doc.id;
              final reason = data['description'] ?? 'ไม่มีเหตุผล';
              final isManual = data['isManual'] ?? false;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: ListTile(
                  leading: Tooltip(
                    message: isManual ? 'เพิ่มโดยแอดมิน' : 'ซิงค์จาก API',
                    child: Icon(
                      isManual ? Icons.person_add_alt_1 : Icons.api,
                      color: isManual ? Colors.blue : Colors.purple,
                    ),
                  ),
                  title: Text(
                    dateId,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(reason),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _confirmDeleteHoliday(dateId),
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

// --- 3. จัดการการจอง (Admin: Manage Reservations) ---
// (คัดลอกไปทับคลาส AdminReservationsPage เดิม)

// (คัดลอกไปทับคลาส AdminReservationsPage เดิม)

// [UI/UX] แปลงเป็น StatefulWidget เพื่อรองรับ Tabs
class AdminReservationsPage extends StatefulWidget {
  const AdminReservationsPage({super.key});

  @override
  State<AdminReservationsPage> createState() => _AdminReservationsPageState();
}

class _AdminReservationsPageState extends State<AdminReservationsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // (ฟังก์ชัน _confirmCancel ไม่เปลี่ยนแปลง)
  Future<void> _confirmCancel(
    BuildContext context,
    Map<String, dynamic> bookingData,
  ) async {
    final bool? shouldCancel = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการยกเลิก'),
        content: Text(
          'คุณต้องการ "ยกเลิก" การจองของ ${bookingData['userName']} ใช่หรือไม่? (Slot จะถูกคืน)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ไม่'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'ใช่, ยกเลิก',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (shouldCancel != true) return;

    try {
      await BookingService.adminCancel(
        bookingId: bookingData['id'],
        roomId: bookingData['roomId'],
        date: bookingData['date'],
        start: bookingData['startTime'],
        end: bookingData['endTime'],
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ยกเลิกการจองสำเร็จ!')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ยกเลิกไม่สำเร็จ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF7A1F1F);

    // [แก้ไข 1/3] ดึงวันที่ปัจจุบัน (ใน Format YYYY-MM-DD)
    final now = DateTime.now();
    final todayString = DateFormat('yyyy-MM-dd').format(now);

    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการการจอง'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          tabs: const [
            Tab(
              text: 'Upcoming',
              icon: Icon(Icons.check_circle_outline),
            ), // 👈 (เปลี่ยนชื่อ)
            Tab(text: 'History', icon: Icon(Icons.history_outlined)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // --- 1. แท็บ "Upcoming" (Active เดิม) ---
          _BookingList(
            query: FirebaseFirestore.instance
                .collection('bookings')
                .where('status', isEqualTo: 'approved')
                .where('date', isGreaterThanOrEqualTo: todayString)
                // [แก้ไข 3/3] เรียงจาก "วันนี้" ไป "อนาคต" (Default is ascending)
                .orderBy('date'), // 👈 ✅ This is the corrected line
            onCancel: _confirmCancel,
          ),

          // --- 2. แท็บ "History" (เหมือนเดิม) ---
          _BookingList(
            query: FirebaseFirestore.instance
                .collection('bookings')
                .where(
                  'status',
                  whereIn: ['canceled', 'admin_canceled', 'rejected'],
                )
                .orderBy('date', descending: true),
            onCancel: null,
            isHistory: true,
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------
// [ 2 ] Widget แสดงรายการ (ไม่เปลี่ยนแปลง)
// -----------------------------------------------------------------
class _BookingList extends StatelessWidget {
  final Query query;
  final Function(BuildContext, Map<String, dynamic>)? onCancel;
  final bool isHistory;

  const _BookingList({
    required this.query,
    this.onCancel,
    this.isHistory = false,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}\n\n[ตรวจสอบ Console เพื่อสร้าง Index ถ้าจำเป็น]',
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final bookings = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'roomId': data['roomId'] ?? 'N/A',
            'uid': data['uid'] ?? 'N/A',
            'userName': data['userName'] ?? 'User ID: ${data['uid']}',
            'roomName': data['roomName'] ?? 'N/A',
            'date': data['date'] ?? 'N/A',
            'startTime': data['start'] ?? 'N/A',
            'endTime': data['end'] ?? 'N/A',
            'status': data['status'] ?? 'N/A',
          };
        }).toList();

        if (bookings.isEmpty) {
          return Center(
            child: Text(
              isHistory
                  ? 'ไม่มีประวัติการจอง'
                  : 'ไม่มีการจองที่กำลังจะมาถึง', // 👈 (เปลี่ยนข้อความ)
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          );
        }

        // (Logic การจัดกลุ่มตามวัน - ดีอยู่แล้ว)
        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final booking = bookings[index];
            final String currentDate = booking['date'];
            final bool isNewDateGroup =
                (index == 0) || (bookings[index - 1]['date'] != currentDate);

            if (isNewDateGroup) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DateHeader(dateStr: currentDate),
                  _BookingTile(
                    booking: booking,
                    isHistory: isHistory,
                    onCancel: onCancel != null
                        ? () => onCancel!(context, booking)
                        : null,
                  ),
                ],
              );
            } else {
              return _BookingTile(
                booking: booking,
                isHistory: isHistory,
                onCancel: onCancel != null
                    ? () => onCancel!(context, booking)
                    : null,
              );
            }
          },
        );
      },
    );
  }
}

// -----------------------------------------------------------------
// [ 3 ] Widget หัวข้อวันที่ (ไม่เปลี่ยนแปลง)
// -----------------------------------------------------------------
class _DateHeader extends StatelessWidget {
  final String dateStr;
  const _DateHeader({required this.dateStr});

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final checkDate = DateTime(date.year, date.month, date.day);

      if (checkDate == today) {
        return 'Today, ${DateFormat('MMM d').format(date)}';
      }
      if (checkDate == tomorrow) {
        return 'Tomorrow, ${DateFormat('MMM d').format(date)}';
      }
      final yesterday = today.subtract(const Duration(days: 1));
      if (checkDate == yesterday) {
        return 'Yesterday, ${DateFormat('MMM d').format(date)}';
      }

      return DateFormat('EEEE, MMM d').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 4),
      child: Text(
        _formatDate(dateStr),
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF7A1F1F),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------
// [ 4 ] Widget Card (ไม่เปลี่ยนแปลง)
// -----------------------------------------------------------------
class _BookingTile extends StatelessWidget {
  final Map<String, dynamic> booking;
  final bool isHistory;
  final VoidCallback? onCancel;

  const _BookingTile({
    required this.booking,
    this.isHistory = false,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final Color textColor = isHistory ? Colors.grey[500]! : Colors.black87;
    final Color iconColor = isHistory ? Colors.grey[400]! : Color(0xFF7A1F1F);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      elevation: isHistory ? 0.5 : 2.0,
      color: isHistory ? Colors.grey[100] : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isHistory ? Colors.grey[300]! : Colors.transparent,
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 16,
        ),
        leading: _DateBox(dateStr: booking['date'], color: iconColor),
        title: Text(
          booking['roomName'],
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textColor,
            decoration: isHistory ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(
          'By: ${booking['userName']}\nTime: ${booking['startTime']} - ${booking['endTime']}',
          style: TextStyle(color: textColor.withOpacity(0.9)),
        ),
        isThreeLine: true,
        trailing: onCancel != null
            ? IconButton(
                icon: Icon(
                  Icons.delete_forever_outlined,
                  color: Colors.red[700],
                ),
                tooltip: 'ยกเลิกการจอง (Admin)',
                onPressed: onCancel,
              )
            : null,
      ),
    );
  }
}

// -----------------------------------------------------------------
// [ 5 ] Widget ไอคอนวันที่ (ไม่เปลี่ยนแปลง)
// -----------------------------------------------------------------
class _DateBox extends StatelessWidget {
  final String dateStr;
  final Color color;
  const _DateBox({required this.dateStr, required this.color});

  @override
  Widget build(BuildContext context) {
    String day = "??";
    String month = "???";

    try {
      final date = DateTime.parse(dateStr);
      day = DateFormat('dd').format(date);
      month = DateFormat('MMM').format(date).toUpperCase();
    } catch (e) {
      // (กัน Error)
    }

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            day,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            month,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
// --------------------------------------------------------------------------
// ADMIN HOME DASHBOARD
// --------------------------------------------------------------------------

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  static const _maroon = Color(0xFF7A1F1F);
  static const _bg = Color(0xFFF6F6F6);

  Future<void> _handleLogout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!context.mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ออกจากระบบไม่สำเร็จ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _FancyAppBar(
            onLogout: () => _handleLogout(context),
            title: 'Admin Dashboard',
            subtitle: 'Room & Booking Management',
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _maroon,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: _AdminQuickActions(), // 👈 (นี่คือ Widget ที่เราจะแก้ไข)
              ),
              const SizedBox(height: 28),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Live Summary',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _maroon,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: _AdminSummary(),
              ),

              // [ลบ] 2. ลบ _NewsPublisher ออกจากหน้านี้
              // (ส่วน "Post Announcement" ที่เคยอยู่ตรงนี้ถูกลบออกแล้ว)
            ]),
          ),
        ],
      ),
    );
  }
}

// --- WIDGETS ---

class _AdminSummary extends StatelessWidget {
  const _AdminSummary();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('bookings')
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return const _SummaryCard(
                icon: Icons.hourglass_empty,
                label: 'Pending Bookings',
                value: '...',
                color: Colors.orange,
              );
            return _SummaryCard(
              icon: Icons.hourglass_empty,
              label: 'Pending Approvals',
              value: snapshot.data!.docs.length.toString(),
              color: Colors.orange,
            );
          },
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('rooms').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return const _SummaryCard(
                icon: Icons.meeting_room,
                label: 'Total Rooms',
                value: '...',
                color: Colors.blue,
              );
            return _SummaryCard(
              icon: Icons.meeting_room,
              label: 'Total Rooms',
              value: snapshot.data!.docs.length.toString(),
              color: Colors.blue,
            );
          },
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(label, style: TextStyle(color: Colors.black54)),
        trailing: Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _FancyAppBar extends StatelessWidget {
  final VoidCallback onLogout;
  final String title;
  final String subtitle;
  const _FancyAppBar({
    required this.onLogout,
    required this.title,
    required this.subtitle,
  });
  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 140,
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 0,
      leadingWidth: 0,
      leading: const SizedBox.shrink(),
      actions: [
        IconButton(
          tooltip: 'ออกจากระบบ',
          onPressed: onLogout,
          icon: const Icon(Icons.logout, color: Colors.black87),
        ),
      ],
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final t =
              ((constraints.biggest.height - kToolbarHeight) /
                      (140 - kToolbarHeight))
                  .clamp(0.0, 1.0);
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, Colors.white.withOpacity(0.92)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 58 - (t * 12),
                      height: 58 - (t * 12),
                      decoration: BoxDecoration(
                        color: AdminHomePage._maroon,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A000000),
                            blurRadius: 16,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.admin_panel_settings_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Opacity(
                            opacity: 0.7 + (0.3 * (1 - t)),
                            child: Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 22 - (t * 2),
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/* ---------------------------- ADMIN QUICK ACTIONS --------------------------- */

class _AdminQuickActions extends StatelessWidget {
  const _AdminQuickActions();

  @override
  Widget build(BuildContext context) {
    // [แก้ไข] 3. เพิ่มรายการที่ 4 (News)
    final items = <({String label, IconData icon, Widget page})>[
      (
        label: 'จัดการห้อง',
        icon: Icons.meeting_room_outlined,
        page: const AdminRoomsPage(),
      ),
      (
        label: 'จัดการวันหยุด',
        icon: Icons.date_range_outlined,
        page: const AdminHolidaysPage(),
      ),
      (
        label: 'จัดการการจอง',
        icon: Icons.list_alt_outlined,
        page: const AdminReservationsPage(),
      ),
      (
        label: 'จัดการข่าวสาร',
        icon: Icons.feed_outlined,
        page: const AdminNewsPage(),
      ), // 👈 ปุ่มใหม่
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      // [แก้ไข] 4. เปลี่ยน Grid เป็น 2x2
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 👈 เปลี่ยนจาก 3 เป็น 2
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.8, // 👈 ปรับอัตราส่วนให้กว้างขึ้น
      ),
      itemBuilder: (context, i) {
        final it = items[i];
        return _ActionTile(
          icon: it.icon,
          label: it.label,
          onTap: () => _navigate(context, it.page),
        );
      },
    );
  }

  void _navigate(BuildContext context, Widget page) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

// (คลาส _ActionTile ไม่เปลี่ยนแปลง)
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF7A1F1F), Color(0xFF9B2C2C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 12,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          // [แก้ไข] 5. ปรับ Layout ภายในปุ่มให้เป็นแนวนอน
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.left, // 👈 ชิดซ้าย
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
