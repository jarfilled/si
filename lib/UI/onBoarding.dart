import 'package:flutter/material.dart';

class OnBoardingPage extends StatefulWidget {
  const OnBoardingPage({super.key});

  @override
  State<OnBoardingPage> createState() => _OnBoardingPageState();
}

class _OnBoardingPageState extends State<OnBoardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const primaryGreen = Color(0xFF42D2A7);
  static const primaryTeal = Color(0xFF45C4D0);
  static const background = Color(0xFFF4F9F7);
  static const text = Color(0xFF263B37);
  static const subtext = Color(0xFF7D8D89);
  static const mint = Color(0xFFE8F8F1);

  final List<Map<String, String>> _pages = [
    {
      'title': 'چشمانت را از صفحه محافظت کن',
      'description': 'با یادآوری فاصله مناسب و استراحت چشم، خستگی دیجیتال را کمتر کن.',
      'image': 'assets/eyeComfort.png',
      'badge': 'قانون ۲۰-۲۰-۲۰',
    },
    {
      'title': 'وضعیت بدنت را بهتر نگه دار',
      'description': 'گردن، کمر، مچ دست و فاصله از گوشی در طول روز پایش می‌شوند.',
      'image': 'assets/backPosture.png',
      'badge': 'پایش زنده',
    },
    {
      'title': 'از داده‌هایت بینش بگیر',
      'description': 'سی فعالیت‌های روزانه را به گزارش‌های ساده تبدیل می‌کند تا بدانید چه چیزی را باید اصلاح کنید.',
      'image': 'assets/history.gif',
      'badge': 'گزارش روزانه',
    },
    {
      'title': 'سلامت فقط وضعیت بدن نیست',
      'description': 'در کنار پایش بدن، آب، حال روحی و عادت‌های روزانه‌ات را هم در یک تجربه یکپارچه دنبال کن.',
      'image': 'assets/meditate.png',
      'badge': 'سلامت کامل‌تر',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage == _pages.length - 1) {
      Navigator.pushReplacementNamed(context, '/signup');
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  void _skip() => Navigator.pushReplacementNamed(context, '/signup');

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 16, offset: const Offset(0, 6)),
                        ],
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Image.asset('assets/logo.png'),
                    ),
                    const Spacer(),
                    if (_currentPage < _pages.length - 1)
                      TextButton(onPressed: _skip, child: const Text('رد کردن')),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (value) => setState(() => _currentPage = value),
                  itemBuilder: (_, index) {
                    final page = _pages[index];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                      child: Column(
                        children: [
                          Expanded(
                            flex: 6,
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: mint,
                                borderRadius: BorderRadius.circular(34),
                              ),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Image.asset(
                                        page['image']!,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 18,
                                    right: 18,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        page['badge']!,
                                        style: const TextStyle(color: primaryGreen, fontWeight: FontWeight.w800, fontSize: 11),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Expanded(
                            flex: 4,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(.045), blurRadius: 24, offset: const Offset(0, 8)),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(page['title']!, style: const TextStyle(color: text, fontSize: 25, fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 10),
                                  Text(page['description']!, style: const TextStyle(color: subtext, fontSize: 13, height: 1.8)),
                                  const Spacer(),
                                  Row(
                                    children: List.generate(
                                      _pages.length,
                                      (dot) => AnimatedContainer(
                                        duration: const Duration(milliseconds: 220),
                                        margin: const EdgeInsets.only(left: 6),
                                        width: dot == _currentPage ? 26 : 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: dot == _currentPage ? primaryGreen : const Color(0xFFE1E8E5),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: Row(
                  children: [
                    if (_currentPage > 0)
                      IconButton(
                        onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                        icon: const Icon(Icons.arrow_forward_rounded, color: text),
                        style: IconButton.styleFrom(backgroundColor: Colors.white),
                      ),
                    if (_currentPage > 0) const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 58,
                        child: ElevatedButton(
                          onPressed: _next,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                          child: Text(
                            _currentPage == _pages.length - 1 ? 'شروع کنید' : 'ادامه',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                          ),
                        ),
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
  }
}
