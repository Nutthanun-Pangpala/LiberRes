# 📚 LiberRes  1.0.2
### *A Library Room Reservation Application*

---

## 📘 คำอธิบายโปรเจค | Project Description

**🇹🇭 ภาษาไทย:**  
LiberRes เป็นแอปพลิเคชันสำหรับการจองห้องภายในห้องสมุดของมหาวิทยาลัย  
ช่วยให้นักศึกษาและบุคลากรสามารถตรวจสอบสถานะห้องว่าง จองเวลา และจัดการการใช้งานได้อย่างสะดวกผ่านสมาร์ตโฟน  
แอปถูกออกแบบให้ใช้งานง่าย มีระบบล็อกอินด้วย **Firebase Authentication**  
และบันทึกข้อมูลการจองใน **Firebase Firestore**  

**🇬🇧 English:**  
LiberRes is a mobile application designed for university students and staff to easily reserve library rooms.  
The app allows users to check room availability, book time slots, and manage their reservations conveniently.  
It uses **Firebase Authentication** for login and **Firestore** as a real-time database to handle booking data securely.  

---

## ⚙️ เทคโนโลยีที่ใช้ | Technologies Used

| หมวดหมู่ (Category) | รายละเอียด (Details) |
|----------------------|-----------------------|
| 🧱 Framework | Flutter (Dart) |
| ☁️ Backend & Database | Firebase Firestore, Firebase Authentication |
| 🔔 Notifications | Firebase Cloud Messaging (FCM) *(optional)* |
| 🎨 UI Library | Material Design Widgets |
| 🧩 Tools | Android Studio / VS Code |

---

## 💡 ฟีเจอร์หลัก | Key Features

**🇹🇭 ภาษาไทย**  
- 🔐 ระบบล็อกอิน / ลงทะเบียนผู้ใช้ผ่าน Firebase  
- 🏫 ตรวจสอบห้องว่างในห้องสมุดแบบเรียลไทม์  
- 🗓️ จองห้องและระบุช่วงเวลาที่ต้องการใช้งาน  
- 🧾 ดูรายการจองของตนเองและยกเลิกการจองได้  
- 📱 รองรับการใช้งานทั้งบน Android และ iOS  
- 🌐 จัดเก็บข้อมูลทั้งหมดบนระบบ Cloud Firestore  

**🇬🇧 English**  
- 🔐 User authentication and registration via Firebase  
- 🏫 Real-time room availability display  
- 🗓️ Booking system with time slot selection  
- 🧾 View and manage user reservations  
- 📱 Cross-platform support (Android & iOS)  
- 🌐 Cloud Firestore integration for secure data storage  

---
## 👨‍💻 ผู้พัฒนา | Developers

**NUTTHANUN PENGPALA**  
📧 6531503025@lamduan.mfu.ac.th  

**KORAWICH SOIN**  
📧 6531503095@lamduan.mfu.ac.th  

**KRITTAYA PHIRASON**  
📧 6531503096@lamduan.mfu.ac.th  

**THANAKRIT SITTIPORNRATTANAMANEE**  
📧 6531503105@lamduan.mfu.ac.th  

🏫 *School of Applied Digital Technology, Mae Fah Luang University.*

## 🚀 วิธีติดตั้งและรันโปรเจค | Installation & Run


```bash
# 1️⃣ Clone โปรเจค
git clone https://github.com/YourUsername/LiberRes.git
cd LiberRes

# 2️⃣ ติดตั้ง dependencies
flutter pub get

# 3️⃣ เชื่อมต่อกับ Firebase
flutterfire configure

# 4️⃣ รันโปรเจค
flutter run


