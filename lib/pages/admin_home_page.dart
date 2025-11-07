import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

// --------------------------------------------------------------------------
// ADMIN FEATURE PAGES (จำลอง UI คล้ายหน้า User Reservations)
// --------------------------------------------------------------------------

// --- 1. จัดการห้อง (Admin: Room Management) ---
class AdminRoomsPage extends StatelessWidget {
  const AdminRoomsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // ในการใช้งานจริง, คุณควรใช้ StreamBuilder หรือ FutureBuilder เพื่อดึงข้อมูลห้องจาก Firestore
    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการห้อง (Rooms)'),
        backgroundColor: const Color(0xFF7A1F1F),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text(
            'Rooms Management: Create, Edit, Delete',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.add_circle_outline, color: Color(0xFF7A1F1F)),
            title: Text('เพิ่มห้องใหม่'),
            trailing: Icon(Icons.arrow_forward_ios),
            onTap: null, // TODO: Implement navigation to Create Room form
          ),
          // TODO: Display list of existing rooms with Edit/Delete buttons
          SizedBox(height: 20),
          Text('รายการห้องที่มีอยู่ (ตัวอย่าง)', style: TextStyle(color: Colors.black54)),
          ListTile(title: Text('Room A'), subtitle: Text('Capacity: 10')),
          ListTile(title: Text('Room B'), subtitle: Text('Capacity: 5')),
        ],
      ),
    );
  }
}

// --- 2. จัดการวันหยุด (Admin: Holiday Management) ---
class AdminHolidaysPage extends StatefulWidget {
  const AdminHolidaysPage({super.key});

  @override
  State<AdminHolidaysPage> createState() => _AdminHolidaysPageState();
}

class _AdminHolidaysPageState extends State<AdminHolidaysPage> {
  final CollectionReference _holidaysRef =
      FirebaseFirestore.instance.collection('holidays');

  // ฟังก์ชันสำหรับเพิ่ม/ลบวันหยุดจะอยู่ที่นี่
  Future<void> _addHoliday() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );

    if (pickedDate != null) {
      final String dateId = DateFormat('yyyy-MM-dd').format(pickedDate);
      await _holidaysRef.doc(dateId).set({
        'reason': 'วันหยุดราชการ/วันสำคัญ',
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เพิ่มวันหยุด $dateId แล้ว')),
      );
    }
  }

  Future<void> _deleteHoliday(String dateId) async {
    await _holidaysRef.doc(dateId).delete();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ลบวันหยุด $dateId แล้ว')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการวันหยุด (Holidays)'),
        backgroundColor: const Color(0xFF7A1F1F),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addHoliday,
        backgroundColor: const Color(0xFF7A1F1F),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _holidaysRef.orderBy('timestamp').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final holidays = snapshot.data!.docs;
          if (holidays.isEmpty) {
            return const Center(child: Text('ไม่มีวันหยุดที่กำหนดไว้'));
          }

          return ListView.builder(
            itemCount: holidays.length,
            itemBuilder: (context, index) {
              final doc = holidays[index];
              final dateId = doc.id;
              final reason = doc['reason'] ?? 'ไม่มีเหตุผล';
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: ListTile(
                  title: Text(dateId, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(reason),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteHoliday(dateId),
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
class AdminReservationsPage extends StatelessWidget {
  const AdminReservationsPage({super.key});

  // ในการใช้งานจริง, คุณต้อง import BookingService และเรียกใช้:
  // BookingService.adminCancel(...)
  Future<void> _confirmCancel(
      BuildContext context, Map<String, dynamic> bookingData) async {
    final bool? shouldCancel = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการยกเลิก'),
        content: Text(
            'คุณต้องการยกเลิกการจองของ User: ${bookingData['userName'] ?? 'N/A'} (ID: ${bookingData['id']}) หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ไม่'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('ใช่, ยกเลิก', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldCancel == true) {
      try {
        // TODO: คุณต้อง implement BookingService.adminCancel() ก่อน
        // await BookingService.adminCancel(
        //   bookingId: bookingData['id'],
        //   roomId: bookingData['roomId'],
        //   date: bookingData['date'],
        //   start: bookingData['startTime'],
        //   end: bookingData['endTime'],
        //   reason: 'Admin cancelled (User No-Show)',
        // );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ยกเลิกการจองสำเร็จ (จำลอง)')),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ยกเลิกไม่สำเร็จ: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ดึงข้อมูลการจองทั้งหมด (ใช้ StreamBuilder หรือ FutureBuilder)
    // สำหรับตัวอย่างนี้, เราจะใช้ StreamBuilder เพื่อดูการจองทั้งหมดจาก collection 'bookings'
    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการการจอง (Reservations)'),
        backgroundColor: const Color(0xFF7A1F1F),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('bookings').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final bookings = snapshot.data!.docs.map((doc) => {
            ...doc.data() as Map<String, dynamic>,
            'id': doc.id,
            // ข้อมูลจำลองสำหรับการแสดงผล
            'userName': 'User ID: ${doc['by']}', 
            'status': doc['status'] ?? 'pending',
          }).toList();

          if (bookings.isEmpty) {
            return const Center(child: Text('ไม่มีการจองที่รอการจัดการ'));
          }

          return ListView.builder(
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: ListTile(
                  leading: Icon(
                    booking['status'] == 'canceled' || booking['status'] == 'admin_canceled' 
                        ? Icons.cancel 
                        : Icons.check_circle, 
                    color: booking['status'] == 'pending' ? Colors.blue : Colors.green
                  ),
                  title: Text(
                      '${booking['roomName'] ?? 'N/A'} (${booking['date'] ?? 'N/A'})'),
                  subtitle: Text(
                      'By: ${booking['userName']}\nTime: ${booking['startTime']} - ${booking['endTime']} | Status: ${booking['status']}'),
                  isThreeLine: true,
                  trailing: (booking['status'] == 'pending' || booking['status'] == 'confirmed')
                      ? IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          tooltip: 'ยกเลิกการจอง (Admin)',
                          onPressed: () => _confirmCancel(context, booking),
                        )
                      : null,
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
// ADMIN HOME DASHBOARD (เทียบเท่า HomePage)
// --------------------------------------------------------------------------

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  static const _maroon = Color(0xFF7A1F1F);
  static const _bg = Color(0xFFF6F6F6);

  Future<void> _handleLogout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!context.mounted) return;
      // กลับหน้า Login และเคลียร์สแตก (Wrapper จะจัดการให้ไปหน้า Login)
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
                    color: Color(0xFF7A1F1F),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: _AdminQuickActions(),
              ),
              const SizedBox(height: 28),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Admin Status/Summary',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7A1F1F),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'ข้อมูลสรุป: การจองที่รอการอนุมัติ, ห้องที่ว่างอยู่, หรือการแจ้งเตือนสำคัญสำหรับผู้ดูแลระบบ',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                ),
              )
            ]),
          ),
        ],
      ),
    );
  }
}

/* --------------------------------- APP BAR -------------------------------- */

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
                        Icons.admin_panel_settings_rounded, // Icon for Admin
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
    final items = <({String label, IconData icon, Widget page})>[
      (label: 'จัดการห้อง', icon: Icons.meeting_room_outlined, page: const AdminRoomsPage()),
      (label: 'จัดการวันหยุด', icon: Icons.date_range_outlined, page: const AdminHolidaysPage()),
      (label: 'จัดการการจอง', icon: Icons.list_alt_outlined, page: const AdminReservationsPage()),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: .90,
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

  void _navigate(
    BuildContext context,
    Widget page,
  ) {
    HapticFeedback.lightImpact();
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => page));
  }
}

// นำ _ActionTile จาก home_page.dart มาใช้
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
          child: Column(
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
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}