import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

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
    required String roomName,
    required String date, // "YYYY-MM-DD"
    required String start, // "HH:mm"
    required String end, // "HH:mm"
    String? uid,
    String? purpose,
  }) async {
    final slots = _slotKeys(start, end);
    if (slots.isEmpty) throw Exception("เวลาไม่ถูกต้อง");

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
          throw Exception("ช่วง $start-$end ของ $date ถูกจองแล้ว");
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
        "roomName": roomName,
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


  // --- START: NEW ADMIN CANCEL FUNCTION ---
  // (อันนี้คุณเพิ่มมา ดีเลยครับ!)
  static Future<void> adminCancel({
    required String bookingId,
    required String roomId,
    required String date, // "YYYY-MM-DD"
    required String start, // "HH:mm"
    required String end, // "HH:mm"
    String reason = 'Admin cancelled (e.g., No-Show or Abuse)',
  }) async {
    final slots = _slotKeys(start, end);
    final dayDoc = _db
        .collection("reservations")
        .doc(roomId)
        .collection("dates")
        .doc(date);
    final bookingRef = _db.collection("bookings").doc(bookingId);

    await _db.runTransaction((tx) async {
      // 1) ลบ slots ทั้งหมดโดยไม่ต้องตรวจสอบว่าใครเป็นคนจอง
      for (final hhmm in slots) {
        final slotRef = dayDoc.collection("slots").doc(hhmm);
        tx.delete(slotRef);
      }
      // 2) อัพเดตสถานะการจองเป็น 'admin_canceled'
      tx.update(bookingRef, {
        "status": "admin_canceled", // สถานะใหม่สำหรับการยกเลิกโดย admin
        "cancellationReason": reason,
        "canceledByAdminAt": FieldValue.serverTimestamp(),
      });
    });
  }

  // --- END: NEW ADMIN CANCEL FUNCTION ---

// --- START: NEW SYNC HOLIDAYS FUNCTION ---
  static Future<void> syncHolidaysFromAPI(int year) async {
    try {
      // 1. เรียก API วันหยุดประเทศไทย (TH)
      final response = await http.get(
          Uri.parse('https://date.nager.at/api/v3/PublicHolidays/$year/TH'));

      if (response.statusCode != 200) {
        throw Exception('Failed to load holidays from API');
      }

      // 2. แปลง JSON
      List<dynamic> apiHolidays = jsonDecode(response.body);

      WriteBatch batch = _db.batch();
      CollectionReference holidaysCollection = _db.collection('holidays');
      int count = 0;

      for (var holiday in apiHolidays) {
        DateTime holidayDate = DateTime.parse(holiday['date']);
        String description = holiday['name']; // 👈 นี่คือชื่อวันหยุดไทย
        String dateId = DateFormat('yyyy-MM-dd').format(holidayDate);

        final data = {
          'description': description,
          'date': Timestamp.fromDate(holidayDate),
          'isManual': false, // 👈 มาจาก API
        };

        // 3. ใช้ .set(..., SetOptions(merge: true))
        // เพื่อ *อัปเดต* วันหยุด API โดยไม่เขียนทับวันที่แอดมินเพิ่มเอง
        var docRef = holidaysCollection.doc(dateId);
        batch.set(docRef, data, SetOptions(merge: true));
        count++;
      }

      await batch.commit();
      print('Successfully synced $count holidays for $year.');

    } catch (e) {
      print('Error syncing holidays: $e');
      rethrow;
    }
  }
  // --- END: NEW SYNC HOLIDAYS FUNCTION ---
  
  // --- START: NEW ADD ROOM FUNCTION (CORRECTED) ---
  // (ย้ายมาไว้ข้างใน class และใช้ static _db)
  static Future<void> addRoom({
    required String roomName,
    required int capacity,
    required List<String> equipment,
  }) async {
    try {
      // อ้างอิงไปยัง Collection 'rooms' โดยใช้ _db ที่มีอยู่
      CollectionReference rooms = _db.collection('rooms');

      // เพิ่มข้อมูลห้องใหม่
      await rooms.add({
        'roomName': roomName,
        'capacity': capacity,
        'equipment': equipment,
        'createdAt': FieldValue.serverTimestamp(), // Optional: เพื่อเก็บเวลาที่สร้าง
      });
      print('Room Added Successfully');
    } catch (e) {
      print('Error adding room: $e');
      // คุณอาจจะ re-throw หรือจัดการ error นี้ใน UI
      rethrow;
    }
  }
  // --- END: NEW ADD ROOM FUNCTION ---

} // <-- นี่คือวงเล็บปิดท้าย Class ครับ