// booking_page.dart (ฉบับแก้ไข Crash และ Overflow)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// สมมติว่าไฟล์ service อยู่ที่นี่ (ตามโค้ดเดิม)
import '../services/booking_service.dart';

class BookingPage extends StatefulWidget {
  const BookingPage({super.key});
  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  // ===== Theme & Open Hours (ใช้ 10:30 - 17:30) =====
  static const Color kMaroon = Color(0xFF8B0000);

  // (กำหนดช่วงเวลาตายตัว 1 ชั่วโมง)
  static const List<Map<String, TimeOfDay>> kFixedSlots = [
    {
      'start': TimeOfDay(hour: 10, minute: 30),
      'end': TimeOfDay(hour: 11, minute: 30),
    },
    {
      'start': TimeOfDay(hour: 11, minute: 30),
      'end': TimeOfDay(hour: 12, minute: 30),
    },
    {
      'start': TimeOfDay(hour: 12, minute: 30),
      'end': TimeOfDay(hour: 13, minute: 30),
    },
    {
      'start': TimeOfDay(hour: 13, minute: 30),
      'end': TimeOfDay(hour: 14, minute: 30),
    },
    {
      'start': TimeOfDay(hour: 14, minute: 30),
      'end': TimeOfDay(hour: 15, minute: 30),
    },
    {
      'start': TimeOfDay(hour: 15, minute: 30),
      'end': TimeOfDay(hour: 16, minute: 30),
    },
    {
      'start': TimeOfDay(hour: 16, minute: 30),
      'end': TimeOfDay(hour: 17, minute: 30),
    },
  ];

  // ===== State =====
  String? _roomId;
  String? _roomName; // (คงไว้จากโค้ด "อันใหม่")
  DateTime _date = DateTime.now();
  final _purposeCtrl = TextEditingController();
  int? _selectedSlotIndex; // Index ของ kFixedSlots ที่ถูกเลือก

  // (คงไว้จากโค้ด "อันใหม่" สำหรับเช็กวันหยุด)
  bool _isHoliday = false;
  bool _isLoadingHoliday = false;
  String _holidayReason = '';

  final _fmtDate = DateFormat("yyyy-MM-dd");
  String get dateStr => _fmtDate.format(_date);

  // ===== Utilities =====
  String _two(int n) => n.toString().padLeft(2, '0');
  String _fmtTime(TimeOfDay t) => '${_two(t.hour)}:${_two(t.minute)}';

  List<String> _keysRange(TimeOfDay a, TimeOfDay b) {
    final keys = <String>[];
    var cur = DateTime(2000, 1, 1, a.hour, a.minute);
    final end = DateTime(2000, 1, 1, b.hour, b.minute);
    while (cur.isBefore(end)) {
      keys.add('${_two(cur.hour)}${_two(cur.minute)}');
      cur = cur.add(const Duration(minutes: 15));
    }
    return keys;
  }

  Set<String> _getKeysForSlot(int index) {
    final slot = kFixedSlots[index];
    return _keysRange(slot['start']!, slot['end']!).toSet();
  }

  // ===== Pickers =====
  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 0)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );

    if (d == null) return;

    setState(() {
      _date = d;
      _isLoadingHoliday = true;
      _isHoliday = false;
      _holidayReason = '';
      _selectedSlotIndex = null;
    });

    try {
      final String dateId = DateFormat('yyyy-MM-dd').format(d);
      final doc = await FirebaseFirestore.instance
          .collection('holidays')
          .doc(dateId)
          .get();

      // ‼️ แก้ไข: ตรวจสอบว่า Widget ยังอยู่ (mounted) ก่อนเรียก setState
      if (!mounted) return;

      if (doc.exists) {
        setState(() {
          _isHoliday = true;
          _holidayReason = doc.data()?['description'] ?? 'วันหยุด';
        });
      }
    } catch (e) {
      print("Error checking holiday: $e");
      // ‼️ แก้ไข: ตรวจสอบ mounted ก่อนเรียก _toast
      if (mounted) {
        _toast("ไม่สามารถตรวจสอบวันหยุดได้ (อาจเกิดจากเครือข่าย)");
      }
    } finally {
      // ‼️ แก้ไข: ตรวจสอบ mounted ก่อนเรียก setState
      if (mounted) {
        setState(() => _isLoadingHoliday = false);
      }
    }
  }

  // ===== Validation =====
  String? _validate(Set<String> busy) {
    if (_isHoliday) return "ไม่สามารถจองได้: $_holidayReason";
    if (_roomId == null) return "กรุณาเลือกห้อง";
    if (_selectedSlotIndex == null) return "กรุณาเลือกช่วงเวลา";

    final keysNeeded = _getKeysForSlot(_selectedSlotIndex!);
    if (keysNeeded.intersection(busy).isNotEmpty) {
      return "ช่วงเวลาที่เลือกมีบางส่วนถูกจองไปแล้ว";
    }
    return null;
  }

  // ===== Submit =====
  Future<void> _submit(Set<String> busy) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _toast("กรุณาเข้าสู่ระบบก่อน");
      return;
    }
    final err = _validate(busy);
    if (err != null) {
      _toast(err);
      return;
    }

    final selectedSlot = kFixedSlots[_selectedSlotIndex!];

    try {
      await BookingService.reserve(
        uid: user.uid,
        roomId: _roomId!,
        roomName: _roomName ?? 'N/A',
        date: dateStr,
        start: _fmtTime(selectedSlot['start']!),
        end: _fmtTime(selectedSlot['end']!),
        purpose: _purposeCtrl.text.trim(),
      );

      // ‼️ แก้ไข: ตรวจสอบ mounted ก่อนเรียก _toast/setState
      if (!mounted) return;
      _purposeCtrl.clear();
      _toast("จองสำเร็จ");
      setState(() {
        _selectedSlotIndex = null;
      });
    } catch (e) {
      // ‼️ แก้ไข: ตรวจสอบ mounted ก่อนเรียก _toast
      if (mounted) {
        _toast(e.toString().replaceFirst("Exception: ", ""));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maroonScheme = Theme.of(context).colorScheme.copyWith(
      primary: kMaroon,
      secondary: kMaroon,
      onPrimary: Colors.white,
      surfaceTint: kMaroon,
    );
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    final slotsStream = (_roomId == null)
        ? const Stream<Set<String>>.empty()
        : FirebaseFirestore.instance
              .collection("reservations")
              .doc(_roomId)
              .collection("dates")
              .doc(dateStr)
              .collection("slots")
              .snapshots()
              .map((qs) => qs.docs.map((d) => d.id).toSet());

    return Theme(
      data: Theme.of(context).copyWith(colorScheme: maroonScheme),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: kMaroon,
          foregroundColor: Colors.white,
          title: const Text("จองห้องสมุด (LiberRes)"),
        ),
        body: StreamBuilder<Set<String>>(
          stream: slotsStream,
          builder: (ctx, snap) {
            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text('เกิดข้อผิดพลาดในการโหลดช่องจอง: ${snap.error}'),
                ),
              );
            }

            final busy = snap.data ?? <String>{};
            final slotsAreLoading =
                snap.connectionState == ConnectionState.waiting;

            return Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  children: [
                    // ===== เลือกห้อง =====
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionTitle(
                              icon: Icons.meeting_room,
                              text: "เลือกห้อง",
                              color: kMaroon,
                            ),
                            const SizedBox(height: 8),
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection("rooms")
                                  .orderBy("roomName")
                                  .snapshots(),
                              builder: (ctx, snap) {
                                final docs = snap.data?.docs ?? [];
                                if (docs.isEmpty) {
                                  return const Text("ยังไม่มีห้องในระบบ");
                                }
                                return Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: docs.map((d) {
                                    final id = d.id;
                                    final name = (d["roomName"] ?? id)
                                        .toString();
                                    final selected = _roomId == id;
                                    return ChoiceChip(
                                      label: Text(name),
                                      selected: selected,
                                      onSelected: (_) {
                                        setState(() {
                                          _roomId = id;
                                          _roomName = name;
                                          _selectedSlotIndex = null;
                                        });
                                      },
                                      selectedColor: kMaroon.withOpacity(.15),
                                      labelStyle: TextStyle(
                                        color: selected
                                            ? kMaroon
                                            : Colors.black87,
                                        fontWeight: selected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                      side: BorderSide(
                                        color: kMaroon.withOpacity(.4),
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                            if (_roomId != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.tag, size: 18, color: kMaroon),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Room ID: $_roomId",
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ===== วันที่ & เวลา (UI ใหม่) =====
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionTitle(
                              icon: Icons.event,
                              text: "วันที่ & เวลา",
                              color: kMaroon,
                            ),
                            const SizedBox(height: 8),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text("วันที่: $dateStr"),
                              trailing: const Icon(Icons.calendar_month),
                              onTap: _pickDate,
                            ),
                            const Divider(),

                            // --- UI ใหม่: Grid ช่วงเวลาตายตัว ---
                            if (_isLoadingHoliday)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (_isHoliday)
                              _InfoBanner(
                                text: "วันที่เลือกเป็นวันหยุด: $_holidayReason",
                                type: BannerType.error,
                                color: Colors.red,
                              )
                            else if (slotsAreLoading &&
                                _roomId != null) // (เพิ่มเช็ก _roomId)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text("กำลังโหลดช่องเวลา..."),
                                ),
                              )
                            else
                              _FixedSlotGrid(
                                busyKeys: busy,
                                selectedIndex: _selectedSlotIndex,
                                onSelect: (index) {
                                  setState(() {
                                    _selectedSlotIndex = index;
                                  });
                                },
                              ),

                            const SizedBox(height: 8),
                            Builder(
                              builder: (_) {
                                final err = _validate(busy);
                                if (err == null) return const SizedBox.shrink();
                                return _InfoBanner(
                                  text: err,
                                  type: BannerType.error,
                                  color: kMaroon,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ===== วัตถุประสงค์ =====
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionTitle(
                              icon: Icons.note_alt,
                              text: "วัตถุประสงค์ (ไม่บังคับ)",
                              color: kMaroon,
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _purposeCtrl,
                              maxLines: 3,
                              decoration: InputDecoration(
                                hintText: "เช่น เตรียมพรีเซนต์, ทำงานกลุ่ม ฯฯ",
                                filled: true,
                                fillColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withOpacity(.2),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: kMaroon.withOpacity(.3),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ===== รายการจองของวัน =====
                    if (_roomId != null &&
                        !_isLoadingHoliday &&
                        !_isHoliday) ...[
                      _SectionHeaderLine(
                        title: "รายการจองของ ${_roomId!} | $dateStr",
                        color: kMaroon,
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection("bookings")
                            .where("roomId", isEqualTo: _roomId)
                            .where("date", isEqualTo: dateStr)
                            .snapshots(),
                        builder: (ctx, snap) {
                          if (snap.hasError) {
                            return Text("เกิดข้อผิดพลาด: ${snap.error}");
                          }
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }

                          final docs = (snap.data?.docs ?? []).toList();
                          docs.sort((a, b) {
                            final ma = a.data() as Map<String, dynamic>;
                            final mb = b.data() as Map<String, dynamic>;
                            return (ma["start"] ?? "").toString().compareTo(
                              (mb["start"] ?? "").toString(),
                            );
                          });

                          if (docs.isEmpty) {
                            return _EmptyState(
                              icon: Icons.event_available,
                              text: "ยังไม่มีการจองสำหรับวันนี้",
                              color: kMaroon,
                            );
                          }

                          return Column(
                            children: docs.map((d) {
                              final m = d.data() as Map<String, dynamic>;
                              final s = (m["status"] ?? "pending").toString();
                              final canceled = s == "canceled";
                              final mine = (m["uid"] ?? "") == currentUserId;
                              return Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: kMaroon.withOpacity(.1),
                                    child: Icon(
                                      canceled ? Icons.block : Icons.schedule,
                                      color: kMaroon,
                                    ),
                                  ),
                                  title: Text("${m["start"]} - ${m["end"]}"),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if ((m["purpose"] ?? "")
                                          .toString()
                                          .isNotEmpty)
                                        Text(m["purpose"]),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: -8,
                                        children: [
                                          _Pill(
                                            text: "สถานะ: $s",
                                            color: kMaroon,
                                          ),
                                          if (mine)
                                            _Pill(
                                              text: "ของฉัน",
                                              icon: Icons.person,
                                              color: kMaroon,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ],
                ),

                // ===== ปุ่มยืนยัน =====
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: SafeArea(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.check_circle),
                      onPressed: (_isHoliday || _isLoadingHoliday)
                          ? null
                          : () => _submit(busy),
                      style: FilledButton.styleFrom(
                        backgroundColor: (_validate(busy) == null)
                            ? kMaroon
                            : Colors.grey,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      label: Text(
                        _isHoliday
                            ? _holidayReason
                            : _selectedSlotIndex == null
                            ? "กรุณาเลือกช่วงเวลา"
                            : "ยืนยันการจอง: ${_fmtTime(kFixedSlots[_selectedSlotIndex!]['start']!)}–${_fmtTime(kFixedSlots[_selectedSlotIndex!]['end']!)}",
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ‼️ แก้ไข: ตรวจสอบ mounted ก่อนเรียก SnackBar
  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ===== UI Components =====

// (UI Widget ใหม่สำหรับแสดง Grid 1-Hour Slots)
class _FixedSlotGrid extends StatelessWidget {
  final Set<String> busyKeys; // "HHmm"
  final int? selectedIndex;
  final ValueChanged<int> onSelect;

  const _FixedSlotGrid({
    required this.busyKeys,
    required this.selectedIndex,
    required this.onSelect,
  });

  // (ดึง 15-min keys สำหรับ 1-hour slot ที่กำหนด)
  Set<String> _getKeysForSlot(int index) {
    final slot = _BookingPageState.kFixedSlots[index];
    // (ย้าย Utilities มาเป็น static หรือ helper ภายนอก)
    // (ในตัวอย่างนี้ เราจะเรียกใช้แบบ Instance ชั่วคราว)
    return _BookingPageState()._keysRange(slot['start']!, slot['end']!).toSet();
  }

  String _fmtTime(TimeOfDay t) =>
      '${_BookingPageState()._two(t.hour)}:${_BookingPageState()._two(t.minute)}';

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 3.5,
      ),
      itemCount: _BookingPageState.kFixedSlots.length, // 7 slots
      itemBuilder: (_, i) {
        final slot = _BookingPageState.kFixedSlots[i];
        final slotStart = slot['start']!;
        final slotEnd = slot['end']!;
        final label = "${_fmtTime(slotStart)} - ${_fmtTime(slotEnd)}";

        final keysNeeded = _getKeysForSlot(i);
        final bool isBusy = keysNeeded.intersection(busyKeys).isNotEmpty;
        final bool isSelected = selectedIndex == i;

        return ElevatedButton(
          onPressed: isBusy ? null : () => onSelect(i),
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected
                ? _BookingPageState.kMaroon
                : (isBusy ? Colors.grey.shade300 : Colors.white),
            foregroundColor: isSelected
                ? Colors.white
                : (isBusy ? Colors.grey.shade500 : _BookingPageState.kMaroon),
            side: BorderSide(color: _BookingPageState.kMaroon.withOpacity(.35)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: isBusy ? 0 : 1,
          ),
          child: Text(label),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _SectionTitle({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          text,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SectionHeaderLine extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionHeaderLine({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ‼️ แก้ไข: ห่อ Padding ด้วย Flexible เพื่อป้องกัน Overflow
        Flexible(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis, // กันข้อความยาวเกิน
            ),
          ),
        ),
        Expanded(child: Divider(color: color.withOpacity(.3))),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color color;
  const _Pill({required this.text, this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final bg = color.withOpacity(.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

enum BannerType { info, error }

class _InfoBanner extends StatelessWidget {
  final String text;
  final BannerType type;
  final Color color;
  const _InfoBanner({
    required this.text,
    required this.type,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isError = type == BannerType.error;
    final c = isError ? Colors.red : color;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withOpacity(.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withOpacity(.3)),
      ),
      child: Row(
        children: [
          Icon(isError ? Icons.error_outline : Icons.info_outline, color: c),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _EmptyState({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(icon, size: 40, color: color),
          const SizedBox(height: 8),
          Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
