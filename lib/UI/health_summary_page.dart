import 'package:flutter/material.dart';
import 'profile_page.dart'; // اضافه شدن ایمپورت صفحه پروفایل

class HealthSummaryPage extends StatelessWidget {
  const HealthSummaryPage({Key? key}) : super(key: key);

  // پالت رنگی اصلی اپلیکیشن S
  final Color mintGreen = const Color(0xFF42D2A7);
  final Color tealColor = const Color(0xFF45C4D0);
  final Color bgColor = const Color(0xFFF5F7FA);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context), // پاس دادن context برای نویگیشن
                const SizedBox(height: 30),
                _buildDailyMetrics(),
                const SizedBox(height: 30),
                _buildActionCards(),
                const SizedBox(height: 30),
                _buildDailyTips(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 1. هدر صفحه شامل خوش‌آمدگویی و پروفایل
  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'سلام، روز بخیر! 👋',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'خلاصه وضعیت امروز',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3142),
              ),
            ),
          ],
        ),
        // اضافه شدن GestureDetector برای هدایت به صفحه پروفایل
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfilePage()),
            );
          },
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [mintGreen, tealColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: mintGreen.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 30),
          ),
        ),
      ],
    );
  }

  // 2. حلقه‌های پیشرفت روزانه (Daily Metrics)
  Widget _buildDailyMetrics() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildProgressRing(
              title: 'فرم گردن',
              percent: 0.85,
              icon: Icons.accessibility_new_rounded,
              color: mintGreen),
          _buildProgressRing(
              title: 'استراحت چشم',
              percent: 0.60,
              icon: Icons.remove_red_eye_rounded,
              color: tealColor),
          _buildProgressRing(
              title: 'تحرک مچ',
              percent: 0.40,
              icon: Icons.back_hand_rounded,
              color: const Color(0xFFFFA62B)), // رنگ مکمل برای جلب توجه
        ],
      ),
    );
  }

  // ویجت سازنده حلقه‌های پیشرفت
  Widget _buildProgressRing({
    required String title,
    required double percent,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 75,
              height: 75,
              child: CircularProgressIndicator(
                value: percent,
                backgroundColor: color.withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                strokeWidth: 8,
                strokeCap: StrokeCap.round,
              ),
            ),
            Icon(icon, color: color, size: 28),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF4A4E69),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${(percent * 100).toInt()}%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // 3. کارت‌های عملیاتی و دسترسی سریع
  Widget _buildActionCards() {
    return Row(
      children: [
        Expanded(
          child: _buildSingleCard(
            title: 'محافظت از چشم',
            subtitle: 'فیلتر نور آبی فعال است',
            icon: Icons.brightness_4_rounded,
            gradient: LinearGradient(
              colors: [mintGreen.withOpacity(0.8), mintGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: _buildSingleCard(
            title: 'آنالیز فرم نشستن',
            subtitle: 'نیاز به اصلاح زاویه',
            icon: Icons.airline_seat_recline_normal_rounded,
            gradient: LinearGradient(
              colors: [tealColor.withOpacity(0.8), tealColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSingleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Gradient gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.last.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // 4. لیست نکات روزانه سلامتی (طراحی حباب دار)
  Widget _buildDailyTips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'توصیه‌های امروز شما',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3142),
          ),
        ),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: mintGreen.withOpacity(0.2), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: mintGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.water_drop_rounded, color: tealColor),
              ),
              const SizedBox(width: 15),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'نوشیدن آب را فراموش نکنید!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF2D3142),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'برای جلوگیری از خشکی چشم در حین کار با صفحه نمایش، هیدراته بمانید.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
