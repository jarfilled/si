import 'package:flutter/material.dart';

class OnBoardingPage extends StatefulWidget {
  const OnBoardingPage({Key? key}) : super(key: key);

  @override
  State<OnBoardingPage> createState() => _OnBoardingPageState();
}

class _OnBoardingPageState extends State<OnBoardingPage> {
  final PageController _pageController = PageController(initialPage: 0);
  int _currentPage = 0;

  // رنگ‌های تم
  final Color primaryGreen = const Color(0xFF42D2A7);
  final Color primaryTeal = const Color(0xFF45C4D0);
  final Color bgColor = const Color(0xFFF4F9F7); // پس‌زمینه روشن‌تر و مدرن‌تر

  final List<Map<String, String>> _pagesData = [
    {
      'title': 'سلامت بینایی',
      'description': 'با پیروی از قانون ۲۰-۲۰-۲۰ از چشمان خود محافظت کنید. خستگی دیجیتالی چشم را به راحتی کاهش دهید.',
      'image': 'assets/eyeComfort.png',
      'bubble': 'هر ۲۰ دقیقه به دور نگاه کن! 👀',
    },
    {
      'title': 'تسکین درد',
      'description': 'وضعیت گردن و مچ دست خود را کنترل کنید تا از فشار و ناراحتی طولانی‌مدت جلوگیری کنید.',
      'image': 'assets/backPosture.png',
      'bubble': 'ستون فقرات خود را در یک راستا نگه دار! ✨',
    },
    {
      'title': 'فرم بدن',
      'description': 'بازخورد در لحظه از وضعیت نشستن خود دریافت کنید و عادت‌های سالم‌تری بسازید.',
      'image': 'assets/wrist_neck.png',
      'bubble': 'صاف بشین! 🧘‍♂️',
    },
    {
      'title': 'سلامت روان',
      'description': 'حالت روحی خود را پیگیری کنید، ضربان قلب خود را زیر نظر بگیرید و مطمئن شوید که ذهن شما به اندازه بدنتان سالم می‌ماند.',
      'image': 'assets/meditate.png',
      'bubble': 'یک نفس عمیق بکش! 🌿',
    },
  ];

  void _goToNextPage() {
    if (_currentPage < _pagesData.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutQuart,
      );
    } else {
      Navigator.pushReplacementNamed(context, '/signup');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      // برای پشتیبانی بهتر از زبان فارسی (راست‌چین)
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Stack(
          children: [
            // اِلِمان‌های تزئینی پس‌زمینه برای پر کردن فضای خالی
            Positioned(
              top: -100,
              right: -50,
              child: CircleAvatar(
                radius: 180,
                backgroundColor: primaryGreen.withOpacity(0.05),
              ),
            ),
            Positioned(
              top: 200,
              left: -80,
              child: CircleAvatar(
                radius: 120,
                backgroundColor: primaryTeal.withOpacity(0.05),
              ),
            ),

            // بخش اسلایدر محتوا
            PageView.builder(
              controller: _pageController,
              onPageChanged: (int page) {
                setState(() {
                  _currentPage = page;
                });
              },
              itemCount: _pagesData.length,
              itemBuilder: (context, index) {
                return _buildPageContent(_pagesData[index], index);
              },
            ),

            // دکمه رد کردن (Skip)
            Positioned(
              top: 50,
              left: 20, // چون به فارسی تغییر داده‌ایم، بهتر است در سمت چپ باشد
              child: AnimatedOpacity(
                opacity: _currentPage == _pagesData.length - 1 ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 300),
                child: TextButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/signup');
                  },
                  child: Text(
                    'رد کردن',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

            // کنترل‌های پایین صفحه (ثابت روی صفحه)
            Positioned(
              bottom: 40,
              left: 30,
              right: 30,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // نشانگر صفحات (Dots)
                  Row(
                    children: List.generate(
                      _pagesData.length,
                          (index) => _buildDotIndicator(index),
                    ),
                  ),
                  // دکمه بعدی / شروع
                  _buildModernButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ساخت محتوای هر صفحه با کارت شناور
  Widget _buildPageContent(Map<String, String> data, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          const SizedBox(height: 100), // فاصله از بالا
          // تصویر و حباب شناور
          Expanded(
            flex: 6,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Image.asset(
                    data['image']!,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: primaryGreen.withOpacity(0.1),
                            blurRadius: 30,
                            spreadRadius: 10,
                          )
                        ],
                      ),
                      child: Icon(
                        Icons.image_outlined,
                        size: 80,
                        color: primaryGreen.withOpacity(0.3),
                      ),
                    ),
                  ),
                ),

                // حباب متنی
                Positioned(
                  top: 20,
                  right: index % 2 == 0 ? 0 : null,
                  left: index % 2 != 0 ? 0 : null,
                  child: _buildSpeechBubble(data['bubble']!, index),
                ),
              ],
            ),
          ),

          // کارت متنی شناور (Floating Card)
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 120, top: 10), // فضای پایین برای دکمه‌ها
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['title']!,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.grey.shade800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    data['description']!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      height: 1.7,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // طراحی حباب متنی
  Widget _buildSpeechBubble(String text, int index) {
    bool isRightSided = index % 2 == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isRightSided ? 0 : 20), // تنظیم شعاع‌ها برای راست‌چین
          bottomRight: Radius.circular(isRightSided ? 20 : 0),
        ),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          color: primaryGreen,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    );
  }

  // نشانگر صفحات
  Widget _buildDotIndicator(int index) {
    bool isActive = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(left: 8),
      height: 8,
      width: isActive ? 28 : 8,
      decoration: BoxDecoration(
        color: isActive ? primaryGreen : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  // دکمه شناور بعدی/شروع
  Widget _buildModernButton() {
    bool isLastPage = _currentPage == _pagesData.length - 1;
    return GestureDetector(
      onTap: _goToNextPage,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack, // افکت ارتجاعی ملایم
        width: isLastPage ? 150 : 70,
        height: 70,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(isLastPage ? 35 : 50),
          gradient: LinearGradient(
            colors: [primaryGreen, primaryTeal],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          boxShadow: [
            BoxShadow(
              color: primaryGreen.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: isLastPage
            ? const Text(
          'شروع کنید',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        )
            : const Icon(
          Icons.arrow_back_rounded,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }
}
