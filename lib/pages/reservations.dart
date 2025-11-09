import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart'; // 👈 (อย่าลืม import intl)

/// ====== THEME ======
const kMaroon = Color(0xFF8B0000); // << ใช้สีเดียวกับหน้า BookingPage
const _bg = Color(0xFFF6F6F6);

enum BookingStatus { pending, approved, rejected, canceled }

extension BookingStatusX on BookingStatus {
  String get value => switch (this) {
    BookingStatus.pending => 'pending',
    BookingStatus.approved => 'approved',
    BookingStatus.rejected => 'rejected',
    BookingStatus.canceled => 'canceled',
  };

  static BookingStatus parse(dynamic s) {
    final v = (s ?? '').toString().toLowerCase();
    return switch (v) {
      'approved' => BookingStatus.approved,
      'rejected' => BookingStatus.rejected,
      'canceled' => BookingStatus.canceled,
      // (สำหรับ Logic เก่า, เราจะไม่เจอ pending จาก user
      // แต่เผื่อ Admin มี Logic 'pending' ก็ใส่ไว้ได้)
      _ => BookingStatus.pending,
    };
  }

  String get label => switch (this) {
    BookingStatus.pending => 'รออนุมัติ',
    BookingStatus.approved => 'อนุมัติแล้ว',
    BookingStatus.rejected => 'ถูกปฏิเสธ',
    BookingStatus.canceled => 'ยกเลิกแล้ว',
  };

  Color get color => switch (this) {
    BookingStatus.pending => const Color(0xFFF59E0B),
    BookingStatus.approved => const Color(0xFF16A34A),
    BookingStatus.rejected => const Color(0xFFDC2626),
    BookingStatus.canceled => Colors.grey,
  };

  IconData get icon => switch (this) {
    BookingStatus.pending => Icons.timelapse_rounded,
    BookingStatus.approved => Icons.verified_rounded,
    BookingStatus.rejected => Icons.block_rounded,
    BookingStatus.canceled => Icons.cancel_rounded,
  };
}

class Booking {
  final String id;
  final String roomId;
  final String roomName;
  final String uid;
  final String date; // YYYY-MM-DD
  final String start; // HH:mm
  final String end; // HH:mm
  final String purpose;
  final BookingStatus status;

  Booking({
    required this.id,
    required this.roomId,
    required this.roomName,
    required this.uid,
    required this.date,
    required this.start,
    required this.end,
    required this.purpose,
    required this.status,
  });

  factory Booking.fromDoc(DocumentSnapshot doc) {
    final m = (doc.data() ?? {}) as Map<String, dynamic>;
    return Booking(
      id: doc.id,
      roomName: (m['roomName'] ?? m['roomId'] ?? '').toString(),
      roomId: (m['roomId'] ?? '').toString(),
      uid: (m['uid'] ?? '').toString(),
      date: (m['date'] ?? '').toString(),
      start: (m['start'] ?? '').toString(),
      end: (m['end'] ?? '').toString(),
      purpose: (m['purpose'] ?? '').toString(),
      status: BookingStatusX.parse(m['status']),
    );
  }
}

/// ================= PAGE =================
class ReservationsPage extends StatefulWidget {
  const ReservationsPage({super.key});
  @override
  State<ReservationsPage> createState() => _ReservationsPageState();
}

class _ReservationsPageState extends State<ReservationsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  DateTime? _dt(String ymd, String hm) {
    try {
      final d = ymd.split('-');
      final t = hm.split(':');
      return DateTime(
        int.parse(d[0]),
        int.parse(d[1]),
        int.parse(d[2]),
        int.parse(t[0]),
        int.parse(t[1]),
      );
    } catch (_) {
      return null;
    }
  }

  String _prettyDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    // (ปรับปรุงเล็กน้อย: ใช้ DateFormat)
    final wd = DateFormat('E', 'th_TH').format(dt); // 'th_TH' เพื่อให้ได้ 'จ'
    if (d == today) return 'วันนี้ ($wd)';
    if (d == today.add(const Duration(days: 1))) return 'พรุ่งนี้ ($wd)';

    // (ปรับปรุงเล็กน้อย: ใช้ DateFormat)
    return DateFormat('d/MM/yyyy ($wd)', 'th_TH').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('กรุณาเข้าสู่ระบบ')));
    }

    final q = FirebaseFirestore.instance
        .collection('bookings')
        .where('uid', isEqualTo: user.uid);

    final maroonScheme = Theme.of(context).colorScheme.copyWith(
      primary: kMaroon,
      secondary: kMaroon,
      onPrimary: Colors.white,
      surfaceTint: kMaroon,
    );

    return Theme(
      data: Theme.of(context).copyWith(colorScheme: maroonScheme),
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          title: const Text('รายการจองของฉัน'),
          backgroundColor: kMaroon,
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: TabBar(
            controller: _tab,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800),
            tabs: const [
              Tab(text: 'กำลังจะมาถึง'),
              Tab(text: 'ประวัติ'), // 👈 (เปลี่ยนชื่อ)
            ],
          ),
        ),
        body: RefreshIndicator(
          color: kMaroon,
          onRefresh: () async =>
              Future<void>.delayed(const Duration(milliseconds: 350)),
          child: StreamBuilder<QuerySnapshot>(
            stream: q.snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return const _NiceError(
                  title: 'โหลดรายการไม่สำเร็จ',
                  subtitle: 'ตรวจสอบการเชื่อมต่อหรือสิทธิ์ Firestore',
                );
              }
              if (!snap.hasData) {
                return const _LoadingList();
              }

              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);

              int cmp(Booking a, Booking b) {
                final adt = _dt(a.date, a.start) ?? DateTime(1970);
                final bdt = _dt(b.date, b.start) ?? DateTime(1970);
                return adt.compareTo(bdt);
              }

              final all = snap.data!.docs.map(Booking.fromDoc).toList();

              // ----------------------------------------------------
              // [ 1. แก้ไข Logic ] "กำลังจะมาถึง"
              // ----------------------------------------------------
              final upcoming = all.where((b) {
                final d = _dt(b.date, b.start);
                // (ต้องสถานะ 'approved' เท่านั้น และ ยังไม่เลยวันนี้)
                return b.status == BookingStatus.approved &&
                    d != null &&
                    !d.isBefore(today);
              }).toList()..sort(cmp); // (เรียงจากเก่าไปใหม่ ถูกแล้ว)

              // ----------------------------------------------------
              // [ 2. แก้ไข Logic ] "ประวัติ" (ที่ผ่านมา)
              // ----------------------------------------------------
              final past = all.where((b) {
                final d = _dt(b.date, b.start);
                // (ถ้าสถานะไม่ใช่ 'approved' เช่น Canceled, Rejected)
                if (b.status != BookingStatus.approved) {
                  return true; // 👈 ให้อยู่ใน "ประวัติ" เสมอ
                }
                // (หรือ ถ้าเป็น 'approved' แต่เลยวันนี้ไปแล้ว)
                return d != null && d.isBefore(today);
              }).toList()..sort(cmp); // (เรียงจากเก่าไปใหม่)

              return TabBarView(
                controller: _tab,
                children: [
                  _FancyList(
                    items: upcoming,
                    emptyTitle: 'ยังไม่มีการจองล่วงหน้า',
                    emptySubtitle: 'เริ่มจองห้องตอนนี้เลย',
                    ctaLabel: 'ไปหน้าจอง',
                    // (onCta คุณอาจจะต้องแก้ /booking เป็น Path ที่ถูกต้อง)
                    onCta: () =>
                        Navigator.of(context).pop(), // 👈 (แก้เป็น Pop)
                    prettyDate: _prettyDate,
                    toDateTime: (b) => _dt(b.date, b.start),
                    allowCancel: true, // 👈 [ใหม่] อนุญาตให้ยกเลิก
                  ),
                  _FancyList(
                    items: past.reversed.toList(), // 👈 (กลับด้าน) ล่าสุดบนสุด
                    emptyTitle: 'ยังไม่มีประวัติการจอง',
                    emptySubtitle: 'เมื่อคุณจองสำเร็จ ประวัติจะมาอยู่ที่นี่',
                    prettyDate: _prettyDate,
                    toDateTime: (b) => _dt(b.date, b.start),
                    allowCancel: false, // 👈 [ใหม่] ไม่อนุญาตให้ยกเลิก
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// ======= LIST with nice UX =======
class _FancyList extends StatelessWidget {
  final List<Booking> items;
  final String emptyTitle;
  final String emptySubtitle;
  final String? ctaLabel;
  final VoidCallback? onCta;
  final String Function(DateTime) prettyDate;
  final DateTime? Function(Booking) toDateTime;
  final bool allowCancel; // 👈 [ใหม่]

  const _FancyList({
    required this.items,
    required this.emptyTitle,
    required this.emptySubtitle,
    this.ctaLabel,
    this.onCta,
    required this.prettyDate,
    required this.toDateTime,
    this.allowCancel = false, // 👈 [ใหม่]
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: _EmptyPretty(
            title: emptyTitle,
            subtitle: emptySubtitle,
            ctaLabel: ctaLabel,
            onCta: onCta,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final b = items[i];
        final dt = toDateTime(b) ?? DateTime.now();
        final headline = prettyDate(dt);

        return Dismissible(
          key: ValueKey(b.id),
          // [แก้ไข] ใช้ 'allowCancel' และเช็คสถานะ
          direction:
              (allowCancel &&
                  b.status == BookingStatus.approved) // 👈 (เช็คสถานะด้วย)
              ? DismissDirection.endToStart
              : DismissDirection.none,
          confirmDismiss: (_) async {
            HapticFeedback.selectionClick();
            return await _confirmCancel(context, b);
          },
          background: const _SwipeBg(),
          child: _BookingCardUX(
            b: b,
            headline: headline,
            // [แก้ไข] ส่ง 'allowCancel' ไปยัง Card
            allowCancel: allowCancel,
          ),
          onDismissed: (_) async {
            // (เราควรเรียก Service.cancel ที่เรามี)
            // (แต่เพื่อความง่าย, ใช้อันเดิมของคุณไปก่อน)
            await FirebaseFirestore.instance
                .collection('bookings')
                .doc(b.id)
                .update({
                  'status': BookingStatus.canceled.value,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('ยกเลิกการจองแล้ว')));
          },
        );
      },
    );
  }

  Future<bool> _confirmCancel(BuildContext context, Booking b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยันการยกเลิก'),
        content: Text(
          'ยกเลิกการจองห้อง ${b.roomName}\n${b.date}  ${b.start}-${b.end}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ไม่ใช่'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยันยกเลิก'),
          ),
        ],
      ),
    );
    return ok == true;
  }
}

class _SwipeBg extends StatelessWidget {
  const _SwipeBg();
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE5E5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(Icons.cancel_rounded, color: Color(0xFFDC2626)),
          SizedBox(width: 8),
          Text(
            'ยกเลิก',
            style: TextStyle(
              color: Color(0xFFDC2626),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// ======= CARD =======
class _BookingCardUX extends StatelessWidget {
  final Booking b;
  final String headline; // วันนี้/พรุ่งนี้/วันที่สวยๆ
  final bool allowCancel; // 👈 [ใหม่]

  const _BookingCardUX({
    required this.b,
    required this.headline,
    required this.allowCancel,
  });

  // [แก้ไข] ใช้ 'allowCancel' และเช็คสถานะ
  bool get _canCancel => allowCancel && (b.status == BookingStatus.approved);

  @override
  Widget build(BuildContext context) {
    final c = b.status.color;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showBottom(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Leading icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [c.withOpacity(.15), c.withOpacity(.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.withOpacity(.35)),
                ),
                alignment: Alignment.center,
                child: Icon(b.status.icon, color: c),
              ),
              const SizedBox(width: 12),
              // Texts
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Room + status chip
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            b.roomName.isEmpty ? 'ไม่ทราบห้อง' : b.roomName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _chip(b.status.label, c),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Date line
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '$headline • ${b.start}–${b.end}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                    if (b.purpose.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.subject_rounded, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              b.purpose,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    // [แก้ไข] ซ่อนปุ่มถ้าไม่สามารถยกเลิกได้
                    if (_canCancel) ...[
                      const SizedBox(height: 10),
                      // Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => _cancel(context),
                            icon: const Icon(Icons.cancel_rounded),
                            label: const Text('ยกเลิกการจอง'),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String text, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(.10),
        border: Border.all(color: c),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c),
      ),
    );
  }

  Future<void> _cancel(BuildContext context) async {
    HapticFeedback.selectionClick();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยันการยกเลิก'),
        content: Text(
          // [แก้ไข] ใช้ roomName
          'ต้องการยกเลิกการจองห้อง ${b.roomName}\n${b.date}  ${b.start}-${b.end} ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ไม่ใช่'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยันยกเลิก'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    // (ในอนาคต ควรเรียก Service.cancel)
    await FirebaseFirestore.instance.collection('bookings').doc(b.id).update({
      'status': BookingStatus.canceled.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ยกเลิกการจองแล้ว')));
    }
  }

  void _showBottom(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 16 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              // [แก้ไข] ใช้ roomName
              b.roomName.isEmpty ? 'ไม่ทราบห้อง' : b.roomName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _pill(icon: Icons.event_rounded, text: b.date),
                _pill(
                  icon: Icons.schedule_rounded,
                  text: '${b.start}–${b.end}',
                ),
                _pill(
                  icon: b.status.icon,
                  text: b.status.label,
                  color: b.status.color,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'วัตถุประสงค์',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(b.purpose.isEmpty ? '-' : b.purpose),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _pill({required IconData icon, required String text, Color? color}) {
    final c = color ?? Colors.black54;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(.08),
        border: Border.all(color: c.withOpacity(.4)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: c),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(color: c, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// ======= EMPTY / LOADING / ERROR =======
class _EmptyPretty extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? ctaLabel;
  final VoidCallback? onCta;
  const _EmptyPretty({
    required this.title,
    required this.subtitle,
    this.ctaLabel,
    this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 160,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [kMaroon.withOpacity(.08), kMaroon.withOpacity(.02)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: kMaroon.withOpacity(.1)),
            borderRadius: BorderRadius.circular(24),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.event_busy_rounded,
            size: 64,
            color: kMaroon.withOpacity(.45),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54),
        ),
        if (ctaLabel != null) ...[
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: kMaroon,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: onCta,
            child: Text(ctaLabel!),
          ),
        ],
      ],
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();
  @override
  Widget build(BuildContext context) {
    Widget skel() => Container(
      height: 96,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kMaroon.withOpacity(.08)),
      ),
    );
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => skel(),
    );
  }
}

class _NiceError extends StatelessWidget {
  final String title;
  final String subtitle;
  const _NiceError({required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 56,
              color: kMaroon.withOpacity(.85),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
