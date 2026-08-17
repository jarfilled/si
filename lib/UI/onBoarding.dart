import 'package:flutter/material.dart';

class OnBoardingPage extends StatefulWidget {
  const OnBoardingPage({super.key});

  @override
  State<OnBoardingPage> createState() => _OnBoardingPageState();
}

class _OnBoardingPageState extends State<OnBoardingPage> {
  final PageController _pageController = PageController(initialPage: 0);
  int _currentPage = 0;

  static const Color primaryGreen = Color(0xFF42D2A7);
  static const Color primaryTeal = Color(0xFF45C4D0);
  static const Color bgColor = Color(0xFFF4F9F7);

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
      'description': 'حالت روحی خود را پیگیری کنید و مطمئن شوید که ذهن شما به اندازه بدنتان سالم می‌ماند.',
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
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 700 || constraints.maxWidth < 360;
            final horizontal = constraints.maxWidth < 360 ? 16.0 : 24.0;
            final bottom = compact ? 20.0 : 34.0;

            return Stack(
              children: [
                Positioned(
                  top: -100,
                  right: -50,
                  child: CircleAvatar(
                    radius: 180,
                    backgroundColor: primaryGreen.withValues(alpha: 0.05),
                  ),
                ),
                Positioned(
                  top: 200,
                  left: -80,
                  child: CircleAvatar(
                    radius: 120,
                    backgroundColor: primaryTeal.withValues(alpha: 0.05),
                  ),
                ),
                PageView.builder(
                  controller: _pageController,
                  onPageChanged: (page) => setState(() => _currentPage = page),
                  itemCount: _pagesData.length,
                  itemBuilder: (context, index) => _buildPageContent(
                    _pagesData[index],
                    index,
                    compact: compact,
                  ),
                ),
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 8,
                  left: 14,
                  child: AnimatedOpacity(
                    opacity: _currentPage == _pagesData.length - 1 ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: TextButton(
                      onPressed: () => Navigator.pushReplacementNamed(context, '/signup'),
                      child: Text(
                        'رد کردن',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: compact ? 14 : 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: MediaQuery.paddingOf(context).bottom + bottom,
                  left: horizontal,
                  right: horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(_pagesData.length, (index) => _buildDotIndicator(index)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildModernButton(compact: compact),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPageContent(
    Map<String, String> data,
    int index, {
    required bool compact,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final topSpace = compact ? 72.0 : 92.0;
        final bottomReserve = compact ? 105.0 : 125.0;
        final textFlex = compact ? 6 : 5;
        final imageFlex = compact ? 5 : 6;
        final cardPadding = compact ? 20.0 : 30.0;
        final titleSize = compact ? 23.0 : 28.0;
        final descriptionSize = compact ? 11.5 : 12.0;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: constraints.maxWidth < 360 ? 16 : 24),
          child: Column(
            children: [
              SizedBox(height: topSpace),
              Expanded(
                flex: imageFlex,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(compact ? 8 : 20),
                      child: Image.asset(
                        data['image']!,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: primaryGreen.withValues(alpha: 0.1),
                                blurRadius: 30,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: Icon(Icons.image_outlined, size: compact ? 60 : 80, color: primaryGreen.withValues(alpha: 0.3)),
                        ),
                      ),
                    ),
                    Positioned(
                      top: compact ? 6 : 20,
                      right: index.isEven ? 0 : null,
                      left: index.isOdd ? 0 : null,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.68),
                        child: _buildSpeechBubble(data['bubble']!, index, compact: compact),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: textFlex,
                child: Container(
                  width: double.infinity,
                  margin: EdgeInsets.only(bottom: bottomReserve, top: 8),
                  padding: EdgeInsets.all(cardPadding),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(compact ? 28 : 40),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['title']!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: titleSize,
                            fontWeight: FontWeight.w900,
                            color: Colors.grey.shade800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          data['description']!,
                          maxLines: compact ? 5 : 6,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: descriptionSize,
                            color: Colors.grey.shade600,
                            height: 1.65,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (availableHeight < 620) const SizedBox(height: 2),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSpeechBubble(String text, int index, {required bool compact}) {
    final isRightSided = index.isEven;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 20, vertical: compact ? 9 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isRightSided ? 0 : 20),
          bottomRight: Radius.circular(isRightSided ? 20 : 0),
        ),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: primaryGreen,
          fontWeight: FontWeight.w800,
          fontSize: compact ? 11 : 14,
        ),
      ),
    );
  }

  Widget _buildDotIndicator(int index) {
    final isActive = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(left: 6),
      height: 7,
      width: isActive ? 24 : 7,
      decoration: BoxDecoration(
        color: isActive ? primaryGreen : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _buildModernButton({required bool compact}) {
    final isLastPage = _currentPage == _pagesData.length - 1;
    return GestureDetector(
      onTap: _goToNextPage,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        width: isLastPage ? (compact ? 126 : 150) : (compact ? 58 : 70),
        height: compact ? 58 : 70,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(isLastPage ? 35 : 50),
          gradient: const LinearGradient(
            colors: [primaryGreen, primaryTeal],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          boxShadow: [
            BoxShadow(
              color: primaryGreen.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: isLastPage
            ? Text('شروع کنید', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: compact ? 15 : 18))
            : Icon(Icons.arrow_back_rounded, color: Colors.white, size: compact ? 27 : 32),
      ),
    );
  }
}
