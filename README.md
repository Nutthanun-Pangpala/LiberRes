📚 LiberRes
A Library Room Reservation Application
📘 คำอธิบายโปรเจค | Project Description
TH 🇹🇭:
LiberRes เป็นแอปพลิเคชันสำหรับการจองห้องภายในห้องสมุดของมหาวิทยาลัย ช่วยให้นักศึกษาและบุคลากรสามารถตรวจสอบสถานะห้องว่าง จองเวลา และจัดการการใช้งานได้อย่างสะดวกผ่านสมาร์ตโฟน แอปถูกออกแบบให้ใช้งานง่าย มีระบบล็อกอินด้วย Firebase Authentication และบันทึกข้อมูลการจองใน Firebase Firestore
EN 🇬🇧:
LiberRes is a mobile application designed for university students and staff to reserve library rooms easily. The app allows users to check room availability, book time slots, and manage their reservations conveniently. It uses Firebase Authentication for login and Firestore as a real-time database to handle booking data securely.
⚙️ เทคโนโลยีที่ใช้ | Technologies Used
หมวดหมู่	รายละเอียด
🧱 Framework	Flutter (Dart)
☁️ Backend & Database	Firebase Firestore, Firebase Authentication
🔔 Notifications	Firebase Cloud Messaging (FCM) (optional)
🎨 UI Library	Material Design Widgets
🧩 Tools	Android Studio / VS Code
💡 ฟีเจอร์หลัก | Key Features
TH 🇹🇭
🔐 ระบบล็อกอิน / ลงทะเบียนผู้ใช้ผ่าน Firebase
🏫 ตรวจสอบห้องว่างในห้องสมุดแบบเรียลไทม์
🗓️ จองห้องและระบุช่วงเวลาที่ต้องการใช้งาน
🧾 ดูรายการจองของตนเองและยกเลิกการจองได้
📱 รองรับการใช้งานทั้งบน Android และ iOS
🌐 จัดเก็บข้อมูลทั้งหมดบนระบบ Cloud Firestore
EN 🇬🇧
🔐 User authentication and registration via Firebase
🏫 Real-time room availability display
🗓️ Booking system with time slot selection
🧾 View and manage user reservations
📱 Cross-platform support (Android & iOS)
🌐 Cloud Firestore integration for secure data storage
🏗️ โครงสร้างโปรเจค (Project Structure)
lib/
├── main.dart                 # Entry point
├── screens/
│   ├── login_screen.dart     # Login & Register pages
│   ├── home_screen.dart      # Show available rooms
│   ├── booking_screen.dart   # Booking details & form
│   └── profile_screen.dart   # User profile & history
├── widgets/
│   └── custom_button.dart    # Reusable UI components
├── services/
│   ├── auth_service.dart     # Handle Firebase Auth
│   └── booking_service.dart  # Firestore operations
└── models/
    └── room_model.dart       # Room data model
🚀 วิธีติดตั้งและรันโปรเจค | Installation & Run
# 1️⃣ Clone โปรเจค
git clone https://github.com/YourUsername/LiberRes.git
cd LiberRes

# 2️⃣ ติดตั้ง dependencies
flutter pub get

# 3️⃣ เชื่อมต่อกับ Firebase
flutterfire configure

# 4️⃣ รันโปรเจค
flutter run
👨‍💻 ผู้พัฒนา | Developer
Nutthanun Pengpala (นัฐธนันท์ เพ็งพลา)
📧 6531503025@lamduan.mfu.ac.th
📧 6531503095@lamduan.mfu.ac.th
📧 6531503096@lamduan.mfu.ac.th
📧 6531503105@lamduan.mfu.ac.th

🏫 School of Applied Digital Technology, Mae Fah Luang University
