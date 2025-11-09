import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class BookingService {
  static final _db = FirebaseFirestore.instance;

  // --- Helpers (ดีอยู่แล้ว) ---
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
      // (สมมติ 15 นาที)
      cur = cur.add(const Duration(minutes: 15));
    }
    return keys;
  }

  // --- [Logic เก่า 1] reserve (จอง + อนุมัติทันที) ---
  /// ตัวอย่างปรับปรุง reserve(...) — แนะนำให้ใช้แทนเวอร์ชันเก่า
  static Future<void> reserve({
    required String roomId,
    required String roomName,
    required String date, // "YYYY-MM-DD"
    required String start, // "HH:mm"
    required String end, // "HH:mm"
    String? uid,
    String? userName,
    String? purpose,
    bool force =
        false, // ถ้า true: พยายามอนุญาตแม้เป็นวันหยุด (ต้องตรวจสิทธิ์เพิ่มเติม)
  }) async {
    final slots = _slotKeys(start, end);
    if (slots.isEmpty) throw Exception("เวลาไม่ถูกต้อง");

    final holidaysRef = _db.collection('holidays').doc(date);

    // 1) เบื้องต้น: ถ้าเป็นวันหยุดและไม่ได้ force ให้หยุดทันที (เร็ว)
    final holidaySnapshot = await holidaysRef.get();
    if (holidaySnapshot.exists && !force) {
      final desc = (holidaySnapshot.data()?['description'] ?? 'วันหยุด');
      throw Exception('ไม่สามารถจองได้ในวันหยุด: $desc');
    }

    final dayDoc = _db
        .collection("reservations")
        .doc(roomId)
        .collection("dates")
        .doc(date);

    final bookingRef = _db.collection("bookings").doc();

    // 2) ทำตรวจสอบสำคัญทั้งหมดใน transaction อีกครั้ง (รวมเช็ก holiday เพื่อป้องกัน race)
    await _db.runTransaction((tx) async {
      // ตรวจ holiday อีกครั้งภายใน transaction
      final holidaySnapInTx = await tx.get(holidaysRef);
      if (holidaySnapInTx.exists && !force) {
        final desc = (holidaySnapInTx.data()?['description'] ?? 'วันหยุด');
        throw Exception('ไม่สามารถจองได้ในวันหยุด: $desc');
      }

      // 1) ตรวจ slot ว่าง
      for (final hhmm in slots) {
        final slotRef = dayDoc.collection("slots").doc(hhmm);
        final snap = await tx.get(slotRef);
        if (snap.exists) {
          throw Exception("ช่วง $start-$end ของ $date ถูกจองแล้ว");
        }
      }

      // 2) ยึด slot
      final now = FieldValue.serverTimestamp();
      for (final hhmm in slots) {
        tx.set(dayDoc.collection("slots").doc(hhmm), {
          "by": uid ?? "guest",
          "at": now,
          "bookingId": bookingRef.id,
        });
      }

      // 3) เขียนใบจองรวม — แนะนำตั้งเป็น pending หากต้องการ workflow ตรวจสอบ
      final bool autoApprove =
          !holidaySnapshot.exists; // ตัวอย่าง: อนุมัติอัตโนมัติถ้าไม่ใช่วันหยุด
      tx.set(bookingRef, {
        "roomId": roomId,
        "roomName": roomName,
        "uid": uid ?? "guest",
        "userName": userName ?? "Guest User",
        "date": date,
        "start": start,
        "end": end,
        "purpose": purpose ?? "",
        "status": autoApprove ? "approved" : "pending",
        "createdAt": now,
        // audit (ถ้ามีการ force ให้บันทึก)
        if (force) "forcedBy": uid ?? "unknown",
        if (force) "forcedAt": now,
        if (holidaySnapshot.exists)
          "holidayReason":
              (holidaySnapshot.data()?['description'] ?? 'วันหยุด'),
      });
    });
  }

  // --- [Logic เก่า 2] cancel (User ยกเลิกเอง) ---
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
        // (เช็คว่าเป็นเจ้าของ Slot จริง)
        if (snap.exists && snap.data()?["by"] == uid) {
          tx.delete(slotRef);
        }
      }
      tx.update(bookingRef, {"status": "canceled"});
    });
  }

  // --- [Logic เก่า 3] adminCancel (Admin ยกเลิก) ---
  static Future<void> adminCancel({
    required String bookingId,
    required String roomId,
    required String date,
    required String start, // "HH:mm"
    required String end, // "HH:mm"
    String reason = 'Admin cancelled',
  }) async {
    final slots = _slotKeys(start, end);
    final dayDoc = _db
        .collection("reservations")
        .doc(roomId)
        .collection("dates")
        .doc(date);
    final bookingRef = _db.collection("bookings").doc(bookingId);

    await _db.runTransaction((tx) async {
      // 1) ลบ slots (Admin ลบได้เลย ไม่ต้องเช็ค)
      for (final hhmm in slots) {
        final slotRef = dayDoc.collection("slots").doc(hhmm);
        tx.delete(slotRef);
      }
      // 2) อัพเดตสถานะ
      tx.update(bookingRef, {
        "status": "admin_canceled",
        "cancellationReason": reason,
        "canceledByAdminAt": FieldValue.serverTimestamp(),
      });
    });
  }

  // --- (ฟังก์ชัน AddRoom - ถูกต้อง) ---
  static Future<void> addRoom({
    required String roomName,
    required int capacity,
    required List<String> equipment,
  }) async {
    await _db.collection('rooms').add({
      'roomName': roomName,
      'capacity': capacity,
      'equipment': equipment,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // --- (ฟังก์ชัน SyncHolidays - ถูกต้อง) ---
  static Future<void> syncHolidaysFromAPI(int year) async {
    try {
      final response = await http.get(
        Uri.parse('https://date.nager.at/api/v3/PublicHolidays/$year/TH'),
      );
      if (response.statusCode != 200)
        throw Exception('Failed to load holidays');

      List<dynamic> apiHolidays = jsonDecode(response.body);
      WriteBatch batch = _db.batch();
      CollectionReference holidaysCollection = _db.collection('holidays');

      for (var holiday in apiHolidays) {
        DateTime holidayDate = DateTime.parse(holiday['date']);
        String description = holiday['name'];
        String dateId = DateFormat('yyyy-MM-dd').format(holidayDate);
        final data = {
          'description': description,
          'date': Timestamp.fromDate(holidayDate),
          'isManual': false,
        };
        var docRef = holidaysCollection.doc(dateId);
        batch.set(docRef, data, SetOptions(merge: true));
      }
      await batch.commit();
    } catch (e) {
      print('Error syncing holidays: $e');
      rethrow;
    }
  }
}