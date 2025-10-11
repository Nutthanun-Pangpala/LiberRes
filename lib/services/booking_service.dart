import 'package:cloud_firestore/cloud_firestore.dart';

class BookingService {
  static final _db = FirebaseFirestore.instance;

  static DateTime _parseHHmm(String hhmm) {
    final h = int.parse(hhmm.substring(0, 2));
    final m = int.parse(hhmm.substring(3, 5));
    return DateTime(2000, 1, 1, h, m);
  }

  static String _toHHmmKey(DateTime t) =>
      '${t.hour.toString().padLeft(2, "0")}${t.minute.toString().padLeft(2, "0")}';

  static List<String> _slotKeys(String startHHmm, String endHHmm) {
    final start = _parseHHmm(startHHmm);
    final end = _parseHHmm(endHHmm);
    final keys = <String>[];
    var cur = start;
    while (cur.isBefore(end)) {
      keys.add(_toHHmmKey(cur));
      cur = cur.add(const Duration(minutes: 15));
    }
    return keys;
  }

  static Future<void> reserve({
    required String roomId,
    required String date, // "YYYY-MM-DD"
    required String start, // "HH:mm"
    required String end, // "HH:mm"
    String? uid,
    String? purpose,
  }) async {
    final slots = _slotKeys(start, end);
    if (slots.isEmpty) throw Exception("เวลาไม่ถูกต้อง");

    // ✅ โหนดวันที่ต้องเป็น 'doc' ก่อนค่อยลงไป 'slots'
    final dayDoc = _db
        .collection("reservations")
        .doc(roomId)
        .collection("dates")
        .doc(date);

    final bookingRef = _db.collection("bookings").doc();

    await _db.runTransaction((tx) async {
      // 1) ตรวจ slot ว่าง
      for (final hhmm in slots) {
        final slotRef = dayDoc.collection("slots").doc(hhmm);
        final snap = await tx.get(slotRef);
        if (snap.exists) {
          throw Exception("ช่วง ${start}-${end} ของ $date ถูกจองแล้ว");
        }
      }
      // 2) ยึด slot
      final now = FieldValue.serverTimestamp();
      for (final hhmm in slots) {
        tx.set(dayDoc.collection("slots").doc(hhmm), {
          "by": uid ?? "guest",
          "at": now,
        });
      }
      // 3) เขียนใบจองรวม
      tx.set(bookingRef, {
        "roomId": roomId,
        "uid": uid ?? "guest",
        "date": date,
        "start": start,
        "end": end,
        "purpose": purpose ?? "",
        "status": "approved",
        "createdAt": now,
      });
    });
  }

  static Future<void> cancel({
    required String bookingId,
    required String roomId,
    required String date,
    required String start,
    required String end,
    required String uid,
  }) async {
    final slots = _slotKeys(start, end);
    final dayDoc = _db
        .collection("reservations")
        .doc(roomId)
        .collection("dates")
        .doc(date);
    final bookingRef = _db.collection("bookings").doc(bookingId);

    await _db.runTransaction((tx) async {
      for (final hhmm in slots) {
        final slotRef = dayDoc.collection("slots").doc(hhmm);
        final snap = await tx.get(slotRef);
        if (snap.exists && snap.data()?["by"] == uid) {
          tx.delete(slotRef);
        }
      }
      tx.update(bookingRef, {"status": "canceled"});
    });
  }
}
