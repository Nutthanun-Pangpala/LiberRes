import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// นำทางไปหน้า Booking จริง
import './booking_page.dart';
import './reservations.dart';
// นำเข้าหน้า Settings
import './settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  // แก้ไข: เปลี่ยนชื่อจาก _maroon เป็น maroon (Public)
  static const maroon = Color(0xFF7A1F1F);
  // แก้ไข: เปลี่ยนชื่อจาก _bg เป็น bg (Public)
  static const bg = Color(0xFFF6F6F6);
  // ลบตัวแปรสีที่ไม่ได้ใช้แล้วออก
  // static const _blue = Color(0xFF1D4ED8);
  // static const _orange = Color(0xFFF59E0B);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// ใช้เป็น key เพื่อบังคับ StreamBuilder rebuild แบบ hard refresh
  int _refreshTick = 0;

  Future<void> _handleRefresh() async {
    // เพิ่มดีเลย์เล็กน้อยเพื่อ UX แล้วบังคับ rebuild
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (mounted) setState(() => _refreshTick++);
  }

  Future<void> _handleLogout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      // กลับหน้า Login และเคลียร์สแตก
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ออกจากระบบไม่สำเร็จ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // แก้ไข: ใช้ HomePage.bg
    return Scaffold(
      backgroundColor: HomePage.bg,
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            _FancyAppBar(onLogout: _handleLogout),
            SliverList(
              delegate: SliverChildListDelegate(const [
                SizedBox(height: 12),
                _ProfileSectionWrapper(),
                SizedBox(height: 20),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: _QuickActions(),
                ),
                SizedBox(height: 28),
                _SectionHeader(title: 'ประกาศล่าสุด'),
                SizedBox(height: 12),
              ]),
            ),
            // แยกส่วน News ออกมาเป็น SliverToBoxAdapter จะได้กด refresh แล้ว rebuild ง่าย
            SliverToBoxAdapter(
              child: _NewsSection(key: ValueKey('news-$_refreshTick')),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        ),
      ),
    );
  }
}

/* --------------------------------- APP BAR -------------------------------- */

class _FancyAppBar extends StatelessWidget {
  final VoidCallback onLogout;
  const _FancyAppBar({required this.onLogout});

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
                        // แก้ไข: ใช้ HomePage.maroon
                        color: HomePage.maroon,
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
                        Icons.menu_book_rounded,
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
                            child: const Text(
                              'LiberRes',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Dashboard',
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

/* ----------------------------- PROFILE SECTION ---------------------------- */

class _ProfileSectionWrapper extends StatelessWidget {
  const _ProfileSectionWrapper();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: _ProfileSkeleton(),
      );
    }
    return _ProfileSection(
      uid: user.uid,
      fallbackEmail: user.email,
      fallbackPhoto: user.photoURL,
    );
  }
}

class _ProfileSection extends StatelessWidget {
  final String uid;
  final String? fallbackEmail;
  final String? fallbackPhoto;
  const _ProfileSection({
    required this.uid,
    this.fallbackEmail,
    this.fallbackPhoto,
  });

  @override
  Widget build(BuildContext context) {
    final doc = FirebaseFirestore.instance.collection('users').doc(uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: doc.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _ProfileSkeleton(),
          );
        }
        if (snapshot.hasError) {
          final email = fallbackEmail ?? '—';
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _ProfileCard(
              studentIdTitle: email.split('@').first,
              email: email,
              role: 'unknown',
              status: 'unknown',
              photoUrl: fallbackPhoto,
              showSetupHint: true,
            ),
          );
        }

        final data = snapshot.data?.data() ?? {};
        final email = (data['email'] ?? fallbackEmail ?? '—').toString();
        final studentId = (data['studentId'] ?? email.split('@').first)
            .toString();
        final role = (data['role'] ?? 'student').toString();
        final status = (data['status'] ?? 'active').toString();
        final photoUrl = (data['photoUrl'] ?? fallbackPhoto);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _ProfileCard(
            studentIdTitle: studentId.isEmpty
                ? 'ยังไม่ได้ตั้งโปรไฟล์'
                : studentId,
            email: email,
            role: role,
            status: status,
            photoUrl: photoUrl,
            showSetupHint: studentId.isEmpty || email == '—',
          ),
        );
      },
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final String studentIdTitle;
  final String email;
  final String role;
  final String status;
  final String? photoUrl;
  final bool showSetupHint;

  const _ProfileCard({
    required this.studentIdTitle,
    required this.email,
    required this.role,
    required this.status,
    this.photoUrl,
    this.showSetupHint = false,
  });

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'active':
        return const Color(0xFF16A34A);
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'suspended':
        return const Color(0xFFDC2626);
      case 'alumni':
        return const Color(0xFF2563EB);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(status);

    Widget chip(String text, Color color, {IconData? icon}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(50),
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
            text.toUpperCase(),
            style: TextStyle(
              fontSize: 12.5,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFFDF6F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFFF0F0F0),
            backgroundImage: (photoUrl != null && '$photoUrl'.isNotEmpty)
                ? NetworkImage(photoUrl!)
                : null,
            child: (photoUrl == null || '$photoUrl'.isEmpty)
                ? const Icon(Icons.person, color: Colors.black54)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  studentIdTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    chip(
                      'role: $role',
                      Colors.black54,
                      icon: Icons.workspace_premium_outlined,
                    ),
                    chip('status: $status', statusColor, icon: Icons.circle),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black45),
                      ),
                    ),
                    if (showSetupHint)
                      TextButton(
                        onPressed: () {
                          // จุดนี้คุณอาจพาไปหน้าแก้โปรไฟล์ในอนาคต
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'ไปที่หน้าแก้ไขโปรไฟล์ (เร็ว ๆ นี้)',
                              ),
                            ),
                          );
                        },
                        child: const Text('ตั้งค่าโปรไฟล์'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget bar({double w = 140, double h = 12}) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: const Color(0xFFE9E9E9),
        borderRadius: BorderRadius.circular(6),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFFE9E9E9),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(w: 120, h: 14),
                const SizedBox(height: 6),
                bar(w: 160),
                const SizedBox(height: 6),
                bar(w: 140),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------------------- QUICK ACTION BUTTONS --------------------------- */

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    // กำหนดข้อมูลปุ่ม โดยไม่ต้องกำหนดสีที่แตกต่างกัน
    final items = <({String label, IconData icon, String route})>[
      (label: 'จองพื้นที่', icon: Icons.menu_book_outlined, route: '/booking'),
      (
        label: 'รายการจอง', // เปลี่ยนจาก Calendar เป็น รายการจอง
        icon: Icons.bookmark_border,
        route: '/reservations',
      ),
      (label: 'การตั้งค่า', icon: Icons.settings_outlined, route: '/settings'),
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
          onTap: () => _navigate(context, it),
        );
      },
    );
  }

  void _navigate(
    BuildContext context,
    ({String label, IconData icon, String route}) it,
  ) {
    HapticFeedback.lightImpact();

    switch (it.route) {
      case '/booking':
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const BookingPage()));
        return;

      case '/reservations':
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ReservationsPage()));
        return;

      // เพิ่มการนำทางไปหน้า Settings
      case '/settings':
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
        return;

      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ยังไม่ได้เตรียมหน้า ${it.label} (${it.route})'),
          ),
        );
    }
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  // ลบ final List<Color> colors; ออก และใช้สีเดิมตามที่ร้องขอ
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
          // กลับไปใช้ Gradient สีแดง/มารูนเดิมสำหรับทุกปุ่ม
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

/* ------------------------------ SECTION HEADER ----------------------------- */

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  const _SectionHeader({required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          if (onSeeAll != null)
            TextButton.icon(
              onPressed: onSeeAll,
              // แก้ไข: ใช้ HomePage.maroon
              style: TextButton.styleFrom(foregroundColor: HomePage.maroon),
              icon: const Icon(Icons.chevron_right),
              label: const Text('ดูทั้งหมด'),
            ),
        ],
      ),
    );
  }
}

/* -------------------------------- NEWS LIST -------------------------------- */

class _NewsSection extends StatelessWidget {
  const _NewsSection({super.key});

  // แก้ไข: ย้ายเมธอด _timeAgo เข้ามาภายในคลาส _NewsSection
  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final now = DateTime.now();
    final dt = ts.toDate();
    final diff = now.difference(dt);

    // กันเคสเวลาอนาคต (นาฬิกาเพี้ยน/ตั้งล่วงหน้า)
    if (diff.isNegative) {
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    }
    if (diff.inSeconds < 60) return 'เมื่อสักครู่';
    if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
    if (diff.inHours < 24) return '${diff.inHours} ชม.ที่แล้ว';
    if (diff.inDays < 7) return '${diff.inDays} วันที่แล้ว';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final newsQuery = FirebaseFirestore.instance
        .collection('news')
        // ถ้าจะเปิด publish-only ให้เอาคอมเมนต์ออกแล้วสร้าง index ตาม error hint ของ Firestore
        // .where('published', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .withConverter<_News>(
          fromFirestore: (s, _) => _News.fromMap(s.id, s.data() ?? {}),
          toFirestore: (v, _) => v.toMap(),
        );

    return StreamBuilder<QuerySnapshot<_News>>(
      stream: newsQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _NewsSkeleton(),
          );
        }
        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _EmptyState(
              icon: Icons.warning_amber_outlined,
              title: 'โหลดประกาศไม่สำเร็จ',
              subtitle: 'ตรวจเน็ต / rules / createdAt',
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _EmptyState(
              icon: Icons.inbox_outlined,
              title: 'ยังไม่มีประกาศ',
              subtitle: 'เพิ่มเอกสารในคอลเลกชัน news แล้วดึงลงเพื่อรีเฟรช',
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final n = docs[i].data();
            // แก้ไข: เรียกใช้เมธอด _timeAgo ภายในคลาส
            return _NewsItem(
              title: n.title,
              subtitle: n.subtitle,
              time: _timeAgo(n.createdAt),
            );
          },
        );
      },
    );
  }
}

class _NewsItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String time;
  const _NewsItem({
    required this.title,
    required this.subtitle,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFEAD1), Color(0xFFFFF3E0)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.campaign_outlined,
              color: Color(0xFF9C6B23),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (time.isNotEmpty)
                      Text(
                        time,
                        style: const TextStyle(
                          color: Colors.black38,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsSkeleton extends StatelessWidget {
  const _NewsSkeleton();

  Widget _bar({double w = 160, double h = 12}) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: const Color(0xFFE9E9E9),
      borderRadius: BorderRadius.circular(6),
    ),
  );

  @override
  Widget build(BuildContext context) {
    Widget item() => Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFE9E9E9),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bar(w: 200, h: 14),
                const SizedBox(height: 6),
                _bar(w: 260),
              ],
            ),
          ),
        ],
      ),
    );

    return Column(children: [item(), const SizedBox(height: 12), item()]);
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 28, color: Colors.black45),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
    return onTap == null
        ? content
        : InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: content,
          );
  }
}

/* --------------------------------- MODELS --------------------------------- */

class _News {
  final String id;
  final String title;
  final String subtitle;
  final Timestamp? createdAt;

  _News({
    required this.id,
    required this.title,
    required this.subtitle,
    this.createdAt,
  });

  /// รองรับกรณีเผลอใส่ createdAt เป็น string/int ใน console
  factory _News.fromMap(String id, Map<String, dynamic> map) {
    Timestamp? ts;
    final raw = map['createdAt'];

    if (raw is Timestamp) {
      ts = raw;
    } else if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) ts = Timestamp.fromDate(parsed);
    } else if (raw is num) {
      // รองรับทั้งวินาทีและมิลลิวินาที
      final ms = raw > 1000000000000 ? raw.toInt() : (raw.toInt() * 1000);
      ts = Timestamp.fromMillisecondsSinceEpoch(ms);
    }

    final title = (map['title'] ?? '').toString();
    final subtitle = (map['subtitle'] ?? '').toString();

    return _News(id: id, title: title, subtitle: subtitle, createdAt: ts);
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'subtitle': subtitle,
    'createdAt': createdAt ?? FieldValue.serverTimestamp(),
  };
}
