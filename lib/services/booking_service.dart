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
      cur = cur.add(const Duration(minutes: 15));
    }
    return keys;
  }

  // --- [Logic แก้ไข] reserve (เพิ่มการตรวจสอบ) ---
  static Future<void> reserve({
    required String roomId,
    required String roomName,
    required String date, // "YYYY-MM-DD"
    required String start, // "HH:mm"
    required String end, // "HH:mm"
    String? uid,
    String? userName,
    String? purpose,
  }) async {
    final slots = _slotKeys(start, end);
    if (slots.isEmpty) throw Exception("เวลาไม่ถูกต้อง");

    // ‼️ [เพิ่มจุดที่ 1] ตรวจสอบเสาร์-อาทิตย์ ‼️
    final DateTime bookingDate;
    try {
      bookingDate = DateTime.parse(date); // date คือ "YYYY-MM-DD"
    } catch (e) {
      throw Exception("รูปแบบวันที่ ($date) ไม่ถูกต้อง");
    }

    if (bookingDate.weekday == DateTime.saturday ||
        bookingDate.weekday == DateTime.sunday) {
      throw Exception("ไม่สามารถจองได้: ปิดทำการ (วันเสาร์-อาทิตย์)");
    }
    // ‼️ [จบจุดที่ 1] ‼️


    final dayDoc = _db
        .collection("reservations")
        .doc(roomId)
        .collection("dates")
        .doc(date);

    final bookingRef = _db.collection("bookings").doc();

    // ‼️ [เพิ่มจุดที่ 2] อ้างอิง doc วันหยุด ‼️
    // เราจะใช้ 'date' (YYYY-MM-DD) ซึ่งตรงกับ ID ของ collection 'holidays'
    final holidayDocRef = _db.collection("holidays").doc(date);
    // ‼️ [จบจุดที่ 2] ‼️


    await _db.runTransaction((tx) async {
    
      // ‼️ [เพิ่มจุดที่ 3] ตรวจสอบวันหยุด (ต้องทำใน Transaction) ‼️
      final holidaySnap = await tx.get(holidayDocRef);
      if (holidaySnap.exists) {
        final reason = holidaySnap.data()?['description'] ?? 'ปิดทำการ';
        // โยน Error ออกไปให้หน้าบ้านรับทราบ
        throw Exception("ไม่สามารถจองได้: $date ($reason)");
      }
      // ‼️ [จบจุดที่ 3] ‼️

      // 1) ตรวจ slot ว่าง (โค้ดเดิม)
      for (final hhmm in slots) {
        final slotRef = dayDoc.collection("slots").doc(hhmm);
        final snap = await tx.get(slotRef);
        if (snap.exists) {
          throw Exception("ช่วง $start-$end ของ $date ถูกจองแล้ว");
        }
      }
      // 2) ยึด slot (โค้ดเดิม)
      final now = FieldValue.serverTimestamp();
      for (final hhmm in slots) {
        tx.set(dayDoc.collection("slots").doc(hhmm), {
          "by": uid ?? "guest",
          "at": now,
          "bookingId": bookingRef.id,
        });
      }
      // 3) เขียนใบจองรวม (โค้ดเดิม)
      tx.set(bookingRef, {
        "roomId": roomId,
        "roomName": roomName,
        "uid": uid ?? "guest",
        "userName": userName ?? "Guest User",
        "date": date,
        "start": start,
        "end": end,
        "purpose": purpose ?? "",
        "status": "approved", 
        "createdAt": now,
      });
    });
  }

  // --- (โค้ดส่วนที่เหลือ... cancel, adminCancel, addRoom, syncHolidays) ---
  // ... (วางโค้ดส่วนที่เหลือของ service.dart ที่คุณมี) ...
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
      for (final hhmm in slots) {
        final slotRef = dayDoc.collection("slots").doc(hhmm);
        tx.delete(slotRef);
      }
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