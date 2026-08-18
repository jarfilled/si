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
    {'title': 'چشمانت را از صفحه محافظت کن', 'description': 'با یادآوری فاصله مناسب و استراحت چشم، خستگی دیجیتال را کمتر کن.', 'image': 'assets/eyeComfort.png', 'badge': 'قانون ۲۰-۲۰-۲۰'},
    {'title': 'وضعیت بدنت را بهتر نگه دار', 'description': 'گردن، کمر، مچ دست و فاصله از گوشی در طول روز پایش می‌شوند.', 'image': 'assets/backPosture.png', 'badge': 'پایش زنده'},
    {'title': 'از داده‌هایت بینش بگیر', 'description': 'سی فعالیت‌های روزانه را به گزارش‌های ساده تبدیل می‌کند تا بدانید چه چیزی را باید اصلاح کنید.', 'image': 'assets/history.png', 'badge': 'گزارش روزانه'},
    {'title': 'سلامت فقط وضعیت بدن نیست', 'description': 'در کنار پایش بدن، آب، حال روحی و عادت‌های روزانه‌ات را هم در یک تجربه یکپارچه دنبال کن.', 'image': 'assets/meditate.png', 'badge': 'سلامت کامل‌تر'},
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
    _pageController.nextPage(duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
  }

  void _skip() => Navigator.pushReplacementNamed(context, '/signup');

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 700;
              final wide = constraints.maxWidth >= 600;
              final horizontal = wide ? 34.0 : 20.0;
              final titleSize = compact ? 21.0 : wide ? 27.0 : 25.0;
              final descriptionSize = compact ? 11.0 : 13.0;

              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(horizontal, compact ? 8 : 12, horizontal, 0),
                    child: Row(children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .04), blurRadius: 16, offset: const Offset(0, 6))]),
                        padding: const EdgeInsets.all(8),
                        child: Image.asset('assets/logo.png'),
                      ),
                      const Spacer(),
                      if (_currentPage < _pages.length - 1) TextButton(onPressed: _skip, child: const Text('رد کردن')),
                    ]),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _pages.length,
                      onPageChanged: (value) => setState(() => _currentPage = value),
                      itemBuilder: (_, index) {
                        final page = _pages[index];
                        return Padding(
                          padding: EdgeInsets.fromLTRB(horizontal, compact ? 10 : 18, horizontal, compact ? 8 : 14),
                          child: Column(children: [
                            Expanded(
                              flex: compact ? 5 : 6,
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(color: mint, borderRadius: BorderRadius.circular(wide ? 36 : 30)),
                                child: Stack(children: [
                                  Positioned.fill(child: Padding(padding: EdgeInsets.all(compact ? 12 : 20), child: Image.asset(page['image']!, fit: BoxFit.contain))),
                                  Positioned(
                                    top: compact ? 10 : 18,
                                    right: compact ? 10 : 18,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(maxWidth: constraints.maxWidth * .42),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                                        child: Text(page['badge']!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: primaryGreen, fontWeight: FontWeight.w800, fontSize: 10)),
                                      ),
                                    ),
                                  ),
                                ]),
                              ),
                            ),
                            SizedBox(height: compact ? 9 : 14),
                            Expanded(
                              flex: compact ? 4 : 4,
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.fromLTRB(wide ? 28 : 22, compact ? 14 : 22, wide ? 28 : 22, compact ? 12 : 18),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .045), blurRadius: 24, offset: const Offset(0, 8))]),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(page['title']!, maxLines: compact ? 2 : 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: text, fontSize: titleSize, height: 1.25, fontWeight: FontWeight.w900)),
                                  SizedBox(height: compact ? 6 : 10),
                                  Expanded(child: Text(page['description']!, maxLines: compact ? 3 : 5, overflow: TextOverflow.ellipsis, style: TextStyle(color: subtext, fontSize: descriptionSize, height: 1.65))),
                                  Row(children: List.generate(_pages.length, (dot) => AnimatedContainer(duration: const Duration(milliseconds: 220), margin: const EdgeInsets.only(left: 6), width: dot == _currentPage ? 26 : 8, height: 8, decoration: BoxDecoration(color: dot == _currentPage ? primaryGreen : const Color(0xFFE1E8E5), borderRadius: BorderRadius.circular(10))))),
                                ]),
                              ),
                            ),
                          ]),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, compact ? 10 : 18),
                    child: Row(children: [
                      if (_currentPage > 0) IconButton(onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut), icon: const Icon(Icons.arrow_forward_rounded, color: text), style: IconButton.styleFrom(backgroundColor: Colors.white)),
                      if (_currentPage > 0) const SizedBox(width: 10),
                      Expanded(child: SizedBox(height: compact ? 50 : 58, child: ElevatedButton(onPressed: _next, style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))), child: Text(_currentPage == _pages.length - 1 ? 'شروع کنید' : 'ادامه', style: TextStyle(fontSize: compact ? 14 : 16, fontWeight: FontWeight.w900))))),
                    ]),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
