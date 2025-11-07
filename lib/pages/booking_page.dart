import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/booking_service.dart';

class BookingPage extends StatefulWidget {
  const BookingPage({super.key});
  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  // ===== Theme & Open Hours =====
  static const Color kMaroon = Color(0xFF8B0000);
  static const int kOpenHour = 9; // 09:00
  static const int kCloseHour = 19; // 19:00 (ไม่รวมปลาย)

  String? _roomId;
  DateTime _date = DateTime.now();
  final _purposeCtrl = TextEditingController();

  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 10, minute: 0);

  final _fmtDate = DateFormat("yyyy-MM-dd");
  String get dateStr => _fmtDate.format(_date);

  // ===== Utilities =====
  String _two(int n) => n.toString().padLeft(2, '0');
  String _fmtTime(TimeOfDay t) => '${_two(t.hour)}:${_two(t.minute)}';
  String _toKey(TimeOfDay t) => '${_two(t.hour)}${_two(t.minute)}';

  TimeOfDay _snap15(TimeOfDay t) {
    int mins = (t.minute / 15.0).round() * 15;
    int h = t.hour, m = mins;
    if (m == 60) {
      h = (h + 1) % 24;
      m = 0;
    }
    return TimeOfDay(hour: h, minute: m);
  }

  int _mins(TimeOfDay t) => t.hour * 60 + t.minute;
  int _durationMins(TimeOfDay a, TimeOfDay b) => _mins(b) - _mins(a);

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

  bool _withinHours(TimeOfDay t) {
    final open = TimeOfDay(hour: kOpenHour, minute: 0);
    final close = TimeOfDay(hour: kCloseHour, minute: 0);
    final tv = _mins(t), ov = _mins(open), cv = _mins(close);
    return tv >= ov && tv <= cv;
  }

  // ===== Pickers =====
  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 0)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (d != null) setState(() => _date = d);
  }

  // กริดเลือกเวลา (09:00–19:00) ช่องที่ถูกจองกดไม่ได้
  Future<TimeOfDay?> _showTimeGrid({
    required Set<String> disabledKeys,
    required String title,
    required TimeOfDay initial,
    int startHour = kOpenHour,
    int endHour = kCloseHour, // ไม่รวมปลาย
  }) async {
    final times = <TimeOfDay>[];
    for (int h = startHour; h < endHour; h++) {
      for (int m = 0; m < 60; m += 15) {
        times.add(TimeOfDay(hour: h, minute: m));
      }
    }
    // เพิ่ม 19:00 สำหรับเวลาสิ้นสุด (ให้เลือก end = 19:00 ได้)
    if (title.contains("สิ้นสุด")) {
      times.add(const TimeOfDay(hour: kCloseHour, minute: 0));
    }

    return await showModalBottomSheet<TimeOfDay>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4, // 4 ช่องต่อแถว
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.6,
                  ),
                  itemCount: times.length,
                  itemBuilder: (_, i) {
                    final t = _snap15(times[i]);
                    final key = '${_two(t.hour)}${_two(t.minute)}';
                    final isBusy = disabledKeys.contains(key);
                    final selected = _toKey(_snap15(initial)) == key;

                    // ปิดช่องถ้าไม่อยู่ใน 09:00–19:00 (ยกเว้น end = 19:00)
                    final inHours = _withinHours(t);
                    final isEnd19 =
                        title.contains("สิ้นสุด") &&
                        t.hour == kCloseHour &&
                        t.minute == 0;
                    final canTap = (inHours || isEnd19) && !isBusy;

                    return ElevatedButton(
                      onPressed: canTap ? () => Navigator.pop(ctx, t) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selected
                            ? kMaroon
                            : (canTap ? Colors.white : Colors.grey.shade300),
                        foregroundColor: selected
                            ? Colors.white
                            : (canTap ? kMaroon : Colors.grey.shade500),
                        side: BorderSide(color: kMaroon.withOpacity(.35)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: canTap ? 1 : 0,
                      ),
                      child: Text(_fmtTime(t)),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ===== Validation =====
  String? _validate(Set<String> busy) {
    if (_roomId == null) return "กรุณาเลือกห้อง";
    if (_fmtTime(_start).compareTo(_fmtTime(_end)) >= 0) {
      return "เวลาเริ่มต้องน้อยกว่าเวลาสิ้นสุด";
    }
    if (!_withinHours(_start) || !_withinHours(_end)) {
      return "เลือกได้เฉพาะช่วง 09:00–19:00";
    }
    if (_durationMins(_start, _end) < 15) {
      return "ระยะเวลาจองต้องอย่างน้อย 15 นาที";
    }
    final need = _keysRange(_start, _end).toSet();
    if (need.intersection(busy).isNotEmpty) {
      return "ช่วงเวลาที่เลือกมีบางช่วงถูกจองแล้ว";
    }
    return null;
  }

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
    try {
      await BookingService.reserve(
        uid: user.uid,
        roomId: _roomId!,
        date: dateStr,
        start: _fmtTime(_start),
        end: _fmtTime(_end),
        purpose: _purposeCtrl.text.trim(),
      );
      _purposeCtrl.clear();
      _toast("จองสำเร็จ");
      setState(() {});
    } catch (e) {
      _toast(e.toString().replaceFirst("Exception: ", ""));
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

    // อ่านช่องเวลาที่จองแล้วจาก reservations/{roomId}/dates/{date}/slots/*
    final slotsStream = (_roomId == null)
        ? const Stream<Set<String>>.empty()
        : FirebaseFirestore.instance
              .collection("reservations")
              .doc(_roomId)
              .collection("dates")
              .doc(dateStr)
              .collection("slots")
              .snapshots()
              .map((qs) => qs.docs.map((d) => d.id).toSet()); // id = "HHmm"

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
            final busy = snap.data ?? <String>{};

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
                                  .orderBy("name")
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
                                    final name = (d["name"] ?? id).toString();
                                    final selected = _roomId == id;
                                    return ChoiceChip(
                                      label: Text(name),
                                      selected: selected,
                                      onSelected: (_) =>
                                          setState(() => _roomId = id),
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

                    // ===== วันที่ & เวลา =====
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

                            Row(
                              children: [
                                Expanded(
                                  child: _TimeTile(
                                    label: "เริ่ม (09:00–19:00)",
                                    time: _fmtTime(_start),
                                    icon: Icons.access_time,
                                    color: kMaroon,
                                    onTap: () async {
                                      final picked = await _showTimeGrid(
                                        disabledKeys: busy,
                                        title: "เลือกเวลาเริ่ม",
                                        initial: _start,
                                        startHour: kOpenHour,
                                        endHour: kCloseHour,
                                      );
                                      if (picked != null) {
                                        final p = _snap15(picked);
                                        setState(() {
                                          _start = p;
                                          if (_fmtTime(
                                                _start,
                                              ).compareTo(_fmtTime(_end)) >=
                                              0) {
                                            final next = TimeOfDay(
                                              hour:
                                                  p.hour +
                                                  ((p.minute + 15) >= 60
                                                      ? 1
                                                      : 0),
                                              minute: (p.minute + 15) % 60,
                                            );
                                            _end = _snap15(next);
                                          }
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _TimeTile(
                                    label: "สิ้นสุด (ถึง 19:00)",
                                    time: _fmtTime(_end),
                                    icon: Icons.access_time_filled,
                                    color: kMaroon,
                                    onTap: () async {
                                      final picked = await _showTimeGrid(
                                        disabledKeys: busy,
                                        title: "เลือกเวลาสิ้นสุด",
                                        initial: _end,
                                        startHour: kOpenHour,
                                        endHour: kCloseHour,
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          _end = _snap15(picked);
                                          if (_fmtTime(
                                                _start,
                                              ).compareTo(_fmtTime(_end)) >=
                                              0) {
                                            final prevMins = _end.minute - 15;
                                            _start = _snap15(
                                              TimeOfDay(
                                                hour:
                                                    _end.hour +
                                                    (prevMins < 0 ? -1 : 0),
                                                minute: (prevMins + 60) % 60,
                                              ),
                                            );
                                          }
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),
                            _SummaryChips(
                              date: dateStr,
                              start: _fmtTime(_start),
                              end: _fmtTime(_end),
                              minutes: _durationMins(_start, _end),
                              color: kMaroon,
                            ),
                            const SizedBox(height: 10),

                            _DayAvailabilityBar(
                              busy: busy,
                              startHour: kOpenHour,
                              endHour: kCloseHour,
                              primary: kMaroon,
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
                                hintText: "เช่น เตรียมพรีเซนต์, ทำงานกลุ่ม ฯลฯ",
                                filled: true,
                                fillColor: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest.withOpacity(.2),
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

                    // ===== รายการจองของวัน (เรียงฝั่ง client; ไม่ต้องมี composite index) =====
                    if (_roomId != null) ...[
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
                            // .orderBy("start") // (ตัดออกเพื่อเลี่ยง index)
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
                          // เรียงตามเวลาเริ่ม (string "HH:mm" เปรียบเทียบได้ตรง)
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

                          final currentUserId =
                              FirebaseAuth.instance.currentUser?.uid ?? "";
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
                      onPressed: () => _submit(busy),
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
                        "ยืนยันการจอง • ${_fmtTime(_start)}–${_fmtTime(_end)} (${_durationMins(_start, _end)} นาที)",
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

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

// ===== UI Components =====

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
        Expanded(child: Divider(color: color.withOpacity(.3))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(child: Divider(color: color.withOpacity(.3))),
      ],
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final String time;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  const _TimeTile({
    required this.label,
    required this.time,
    required this.icon,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: color.withOpacity(.08),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      title: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
      ),
      subtitle: Text(time, style: Theme.of(context).textTheme.titleMedium),
      trailing: Icon(icon, color: color),
      onTap: onTap,
    );
  }
}

class _SummaryChips extends StatelessWidget {
  final String date;
  final String start;
  final String end;
  final int minutes;
  final Color color;
  const _SummaryChips({
    required this.date,
    required this.start,
    required this.end,
    required this.minutes,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        _Pill(text: date, icon: Icons.calendar_today, color: color),
        _Pill(text: "$start–$end", icon: Icons.schedule, color: color),
        _Pill(
          text: "$minutes นาที",
          icon: Icons.hourglass_bottom,
          color: color,
        ),
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

/// แถบแสดงความพร้อมใช้งานวันนั้น (สีแดง = ถูกจองแล้ว) จำกัด 09:00–19:00
class _DayAvailabilityBar extends StatelessWidget {
  final Set<String> busy; // id = "HHmm"
  final int startHour;
  final int endHour; // ไม่รวม
  final Color primary;
  const _DayAvailabilityBar({
    required this.busy,
    required this.startHour,
    required this.endHour,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final keys = <String>[];
    for (int h = startHour; h < endHour; h++) {
      for (int m = 0; m < 60; m += 15) {
        keys.add(
          '${h.toString().padLeft(2, '0')}${m.toString().padLeft(2, '0')}',
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          children: [
            _Legend(color: primary, text: "ถูกจอง"),
            _Legend(color: Colors.grey.shade300, text: "ว่าง"),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (ctx, c) {
            final width = c.maxWidth;
            final barH = 14.0;
            final slotW = width / keys.length;
            return Container(
              height: barH,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade300,
              ),
              clipBehavior: Clip.antiAlias,
              child: Row(
                children: keys.map((k) {
                  final booked = busy.contains(k);
                  return SizedBox(
                    width: slotW,
                    height: barH,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: booked ? primary : Colors.transparent,
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String text;
  const _Legend({required this.color, required this.text});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(text),
      ],
    );
  }
}
