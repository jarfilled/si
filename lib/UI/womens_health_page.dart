import 'dart:math' as math;
import 'package:flutter/material.dart';

class WomensHealthPage extends StatefulWidget {
  const WomensHealthPage({Key? key}) : super(key: key);

  @override
  State<WomensHealthPage> createState() => _WomensHealthPageState();
}

class _WomensHealthPageState extends State<WomensHealthPage> {
  final Color primaryGreen = const Color(0xFF42D2A7);
  final Color darkTeal = const Color(0xFF145954);
  final Color bgColor = const Color(0xFFF7F9F9);
  final Color softPink = const Color(0xFFFFA5B7);
  final Color lightPink = const Color(0xFFFFEEF2);
  final Color mutedText = const Color(0xFF71807F);

  int painLevel = 5;
  int moodLevel = 3;
  int energyLevel = 3;

  bool heatTried = false;
  bool hydrationTried = false;
  bool movementTried = false;

  final List<double> painHistory = [3, 4, 4, 6, 5, 7, 5];
  final List<double> moodHistory = [4, 3, 3, 2, 3, 2, 3];
  final List<double> energyHistory = [4, 4, 3, 2, 2, 3, 3];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'سلامت و قاعدگی',
            style: TextStyle(
              color: darkTeal,
              fontWeight: FontWeight.bold,
            ),
          ),
          iconTheme: IconThemeData(color: darkTeal),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 5, 20, 35),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCycleOverview(),

              const SizedBox(height: 22),

              _buildPmsStatusCard(),

              const SizedBox(height: 28),

              _sectionTitle('وضعیت امروز'),

              const SizedBox(height: 14),

              _buildPainCard(),

              const SizedBox(height: 18),

              _buildMoodEnergyCard(),

              const SizedBox(height: 28),

              _sectionTitle('روند علائم'),

              const SizedBox(height: 14),

              _buildPainChartCard(),

              const SizedBox(height: 16),

              _buildMoodChartCard(),

              const SizedBox(height: 28),

              _sectionTitle('چه چیزی می‌تواند کمک کند؟'),

              const SizedBox(height: 14),

              _buildPainManagementCard(),

              const SizedBox(height: 16),

              _buildDistractionCard(),

              const SizedBox(height: 28),

              _sectionTitle('ثبت روزانه'),

              const SizedBox(height: 14),

              _buildDailyLogCard(),

              const SizedBox(height: 24),

              _buildSafetyCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: darkTeal,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CYCLE OVERVIEW
  // ---------------------------------------------------------------------------

  Widget _buildCycleOverview() {
    const int currentDay = 14;
    const int cycleLength = 28;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: softPink.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: lightPink,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.calendar_month_rounded,
                  color: softPink,
                  size: 26,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'چرخه فعلی',
                      style: TextStyle(
                        fontSize: 13,
                        color: mutedText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'روز $currentDay از حدود $cycleLength روز',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: darkTeal,
                      ),
                    ),
                  ],
                ),
              ),
              _phaseBadge('فاز میانی'),
            ],
          ),

          const SizedBox(height: 22),

          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: currentDay / cycleLength,
              minHeight: 11,
              backgroundColor: bgColor,
              valueColor: AlwaysStoppedAnimation<Color>(softPink),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'شروع چرخه',
                style: TextStyle(fontSize: 11, color: mutedText),
              ),
              Text(
                'روز $currentDay',
                style: TextStyle(
                  fontSize: 11,
                  color: softPink,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'چرخه بعدی',
                style: TextStyle(fontSize: 11, color: mutedText),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _phaseBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: lightPink,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: softPink,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PMS STATUS
  // ---------------------------------------------------------------------------

  Widget _buildPmsStatusCard() {
    final bool significantSymptoms = painLevel >= 7 || moodLevel <= 2;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            softPink.withOpacity(0.18),
            primaryGreen.withOpacity(0.08),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: softPink.withOpacity(0.22),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              shape: BoxShape.circle,
            ),
            child: Icon(
              significantSymptoms
                  ? Icons.favorite_border_rounded
                  : Icons.spa_rounded,
              color: softPink,
              size: 29,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  significantSymptoms
                      ? 'امروز کمی بیشتر مراقب خودت باش'
                      : 'وضعیت امروزت ثبت شد',
                  style: TextStyle(
                    color: darkTeal,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  significantSymptoms
                      ? 'علائم ثبت‌شده نشان می‌دهند بهتر است امروز فشار کمتری به خودت وارد کنی.'
                      : 'با ثبت روزانه علائم، سی می‌تواند الگوی علائم تو را در چرخه‌های بعدی بهتر نشان دهد.',
                  style: TextStyle(
                    color: mutedText,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PAIN
  // ---------------------------------------------------------------------------

  Widget _buildPainCard() {
    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(
                Icons.monitor_heart_outlined,
                softPink,
                lightPink,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'میزان درد امروز',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: darkTeal,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'شدت درد را از ۰ تا ۱۰ مشخص کن',
                      style: TextStyle(
                        fontSize: 11,
                        color: mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$painLevel/10',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _painColor(painLevel),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: _painColor(painLevel),
              inactiveTrackColor: bgColor,
              thumbColor: _painColor(painLevel),
              overlayColor: _painColor(painLevel).withOpacity(0.12),
              trackHeight: 8,
            ),
            child: Slider(
              min: 0,
              max: 10,
              divisions: 10,
              value: painLevel.toDouble(),
              onChanged: (value) {
                setState(() {
                  painLevel = value.round();
                });
              },
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'بدون درد',
                style: TextStyle(fontSize: 10, color: mutedText),
              ),
              Text(
                'متوسط',
                style: TextStyle(fontSize: 10, color: mutedText),
              ),
              Text(
                'شدید',
                style: TextStyle(fontSize: 10, color: mutedText),
              ),
            ],
          ),

          const SizedBox(height: 18),

          _buildPainInterpretation(),
        ],
      ),
    );
  }

  Widget _buildPainInterpretation() {
    String title;
    String description;
    IconData icon;

    if (painLevel <= 2) {
      title = 'درد خفیف';
      description =
      'اگر فعالیت‌های روزانه‌ات بدون مشکل انجام می‌شوند، استراحت کوتاه و مراقبت معمول کافی است.';
      icon = Icons.sentiment_satisfied_alt_rounded;
    } else if (painLevel <= 5) {
      title = 'درد قابل توجه';
      description =
      'می‌توانی شدت فعالیت را کمتر کنی و از روش‌های ساده برای راحت‌تر شدن استفاده کنی.';
      icon = Icons.sentiment_neutral_rounded;
    } else if (painLevel <= 7) {
      title = 'درد نسبتاً شدید';
      description =
      'اگر درد تمرکز یا فعالیت روزانه‌ات را مختل می‌کند، امروز زمان خوبی برای کاهش فشار و مراقبت از خودت است.';
      icon = Icons.sentiment_dissatisfied_rounded;
    } else {
      title = 'درد شدید';
      description =
      'اگر این شدت درد برایت غیرمعمول است، ادامه‌دار می‌شود یا فعالیت‌های معمولت را مختل کرده، بهتر است با یک متخصص سلامت صحبت کنی.';
      icon = Icons.warning_amber_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _painColor(painLevel).withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: _painColor(painLevel),
            size: 25,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: darkTeal,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: mutedText,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _painColor(int value) {
    if (value <= 2) return primaryGreen;
    if (value <= 5) return Colors.orangeAccent;
    if (value <= 7) return Colors.deepOrangeAccent;
    return Colors.redAccent;
  }

  // ---------------------------------------------------------------------------
  // MOOD + ENERGY
  // ---------------------------------------------------------------------------

  Widget _buildMoodEnergyCard() {
    return _whiteCard(
      child: Column(
        children: [
          _buildMetricSlider(
            title: 'خلق‌وخو',
            subtitle: 'امروز از نظر روحی چطوری؟',
            icon: Icons.mood_rounded,
            color: Colors.orangeAccent,
            value: moodLevel,
            onChanged: (value) {
              setState(() {
                moodLevel = value;
              });
            },
          ),
          const SizedBox(height: 22),
          _buildMetricSlider(
            title: 'انرژی',
            subtitle: 'چقدر انرژی برای فعالیت داری؟',
            icon: Icons.bolt_rounded,
            color: primaryGreen,
            value: energyLevel,
            onChanged: (value) {
              setState(() {
                energyLevel = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricSlider({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      children: [
        Row(
          children: [
            _iconBox(
              icon,
              color,
              color.withOpacity(0.10),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: darkTeal,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: mutedText,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '$value/5',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: color,
            inactiveTrackColor: bgColor,
            thumbColor: color,
            trackHeight: 6,
          ),
          child: Slider(
            min: 1,
            max: 5,
            divisions: 4,
            value: value.toDouble(),
            onChanged: (newValue) {
              onChanged(newValue.round());
            },
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // CHARTS
  // ---------------------------------------------------------------------------

  Widget _buildPainChartCard() {
    return _chartCard(
      title: 'روند درد',
      subtitle: '۷ روز گذشته',
      icon: Icons.show_chart_rounded,
      color: softPink,
      data: painHistory,
      maxValue: 10,
      labels: const ['۷ روز پیش', 'امروز'],
    );
  }

  Widget _buildMoodChartCard() {
    return _chartCard(
      title: 'روند خلق‌وخو و انرژی',
      subtitle: 'مقایسه هفت روز گذشته',
      icon: Icons.insights_rounded,
      color: primaryGreen,
      data: moodHistory,
      secondaryData: energyHistory,
      maxValue: 5,
      labels: const ['۷ روز پیش', 'امروز'],
    );
  }

  Widget _chartCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<double> data,
    required double maxValue,
    required List<String> labels,
    List<double>? secondaryData,
  }) {
    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(
                icon,
                color,
                color.withOpacity(0.10),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: darkTeal,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: mutedText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          SizedBox(
            height: 150,
            width: double.infinity,
            child: CustomPaint(
              painter: _LineChartPainter(
                primaryData: data,
                secondaryData: secondaryData,
                maxValue: maxValue,
                primaryColor: color,
                secondaryColor: secondaryData != null
                    ? softPink
                    : null,
                gridColor: bgColor,
              ),
            ),
          ),

          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                labels[0],
                style: TextStyle(
                  color: mutedText,
                  fontSize: 10,
                ),
              ),
              Text(
                labels[1],
                style: TextStyle(
                  color: mutedText,
                  fontSize: 10,
                ),
              ),
            ],
          ),

          if (secondaryData != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _chartLegend(primaryGreen, 'خلق‌وخو'),
                const SizedBox(width: 18),
                _chartLegend(softPink, 'انرژی'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _chartLegend(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            fontSize: 10,
            color: mutedText,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // PAIN MANAGEMENT
  // ---------------------------------------------------------------------------

  Widget _buildPainManagementCard() {
    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'چند گزینه ساده برای امتحان کردن',
            style: TextStyle(
              color: darkTeal,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'می‌توانی مواردی را که امتحان کرده‌ای علامت بزنی تا سی بهتر متوجه شود چه چیزهایی برایت مفید بوده‌اند.',
            style: TextStyle(
              color: mutedText,
              fontSize: 11,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 15),

          _buildActionTile(
            icon: Icons.local_fire_department_outlined,
            title: 'گرمای ملایم',
            description: 'استفاده از کیسه آب گرم می‌تواند به آرام شدن گرفتگی‌ها کمک کند.',
            color: softPink,
            checked: heatTried,
            onTap: () {
              setState(() {
                heatTried = !heatTried;
              });
            },
          ),

          _buildActionTile(
            icon: Icons.water_drop_outlined,
            title: 'آب کافی',
            description: 'نوشیدن مایعات کافی و داشتن وعده‌های منظم می‌تواند کمک‌کننده باشد.',
            color: primaryGreen,
            checked: hydrationTried,
            onTap: () {
              setState(() {
                hydrationTried = !hydrationTried;
              });
            },
          ),

          _buildActionTile(
            icon: Icons.directions_walk_rounded,
            title: 'حرکت سبک',
            description: 'پیاده‌روی یا کشش سبک، اگر بدنت اجازه می‌دهد، می‌تواند گزینه خوبی باشد.',
            color: Colors.orangeAccent,
            checked: movementTried,
            onTap: () {
              setState(() {
                movementTried = !movementTried;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required bool checked,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: checked
              ? color.withOpacity(0.08)
              : bgColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: checked
                ? color.withOpacity(0.35)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 21,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: darkTeal,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: TextStyle(
                      color: mutedText,
                      fontSize: 10,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              checked
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
              color: checked ? color : Colors.grey[400],
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DISTRACTION / SOCIAL SUPPORT
  // ---------------------------------------------------------------------------

  Widget _buildDistractionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: darkTeal,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'لا لازم نیست تمام توجهت روی درد باشد',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            'اگر درد اذیتت می‌کند، یک فعالیت آرام و لذت‌بخش هم می‌تواند کمک کند که ذهنت کمتر درگیر ناراحتی باشد.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.78),
              fontSize: 11,
              height: 1.6,
            ),
          ),

          const SizedBox(height: 15),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSuggestionChip(
                Icons.phone_rounded,
                'با یک دوست تماس بگیر',
              ),
              _buildSuggestionChip(
                Icons.music_note_rounded,
                'موسیقی گوش بده',
              ),
              _buildSuggestionChip(
                Icons.movie_outlined,
                'یک فیلم ببین',
              ),
              _buildSuggestionChip(
                Icons.menu_book_rounded,
                'کتاب بخوان',
              ),
              _buildSuggestionChip(
                Icons.self_improvement_rounded,
                'چند دقیقه آرام باش',
              ),
              _buildSuggestionChip(
                Icons.brush_rounded,
                'یک کار خلاقانه',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: primaryGreen,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DAILY LOG
  // ---------------------------------------------------------------------------

  Widget _buildDailyLogCard() {
    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'یادداشت امروز',
            style: TextStyle(
              color: darkTeal,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'چیزی هست که دوست داری درباره امروز ثبت کنی؟',
            style: TextStyle(
              color: mutedText,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 13),
          TextField(
            maxLines: 4,
            textDirection: TextDirection.rtl,
            decoration: InputDecoration(
              hintText: 'مثلاً: امروز گرفتگی بیشتری داشتم...',
              hintStyle: TextStyle(
                color: Colors.grey[400],
                fontSize: 11,
              ),
              filled: true,
              fillColor: bgColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(
                  color: primaryGreen.withOpacity(0.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(
                Icons.check_rounded,
                size: 18,
              ),
              label: const Text(
                'ثبت اطلاعات امروز',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: darkTeal,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SAFETY
  // ---------------------------------------------------------------------------

  Widget _buildSafetyCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: Colors.orangeAccent.withOpacity(0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Colors.orangeAccent,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'اگر درد بسیار شدید یا غیرمعمول است، ناگهان بدتر شده، باعث اختلال جدی در فعالیت‌های روزانه می‌شود یا با علائم نگران‌کننده دیگری همراه است، بهتر است به جای تکیه بر این صفحه با پزشک یا متخصص سلامت مشورت شود.',
              style: TextStyle(
                color: mutedText,
                fontSize: 10,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // COMMON UI
  // ---------------------------------------------------------------------------

  Widget _whiteCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _iconBox(
      IconData icon,
      Color color,
      Color background,
      ) {
    return Container(
      width: 43,
      height: 43,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(
        icon,
        color: color,
        size: 22,
      ),
    );
  }
}

// ============================================================================
// SIMPLE LINE CHART
// ============================================================================

class _LineChartPainter extends CustomPainter {
  final List<double> primaryData;
  final List<double>? secondaryData;
  final double maxValue;
  final Color primaryColor;
  final Color? secondaryColor;
  final Color gridColor;

  _LineChartPainter({
    required this.primaryData,
    required this.secondaryData,
    required this.maxValue,
    required this.primaryColor,
    required this.secondaryColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (primaryData.isEmpty) return;

    final double left = 10;
    final double right = size.width - 10;
    final double top = 8;
    final double bottom = size.height - 12;

    final Paint gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final double y =
          top + ((bottom - top) / 4) * i;

      canvas.drawLine(
        Offset(left, y),
        Offset(right, y),
        gridPaint,
      );
    }

    _drawLine(
      canvas,
      size,
      primaryData,
      primaryColor,
      left,
      right,
      top,
      bottom,
    );

    if (secondaryData != null &&
        secondaryData!.isNotEmpty &&
        secondaryColor != null) {
      _drawLine(
        canvas,
        size,
        secondaryData!,
        secondaryColor!,
        left,
        right,
        top,
        bottom,
      );
    }
  }

  void _drawLine(
      Canvas canvas,
      Size size,
      List<double> data,
      Color color,
      double left,
      double right,
      double top,
      double bottom,
      ) {
    if (data.length < 2) return;

    final Paint linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Paint pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final Path path = Path();

    for (int i = 0; i < data.length; i++) {
      final double x = left +
          (right - left) *
              (i / (data.length - 1));

      final double normalized =
      (data[i] / maxValue).clamp(0.0, 1.0);

      final double y =
          bottom - (bottom - top) * normalized;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, linePaint);

    for (int i = 0; i < data.length; i++) {
      final double x = left +
          (right - left) *
              (i / (data.length - 1));

      final double normalized =
      (data[i] / maxValue).clamp(0.0, 1.0);

      final double y =
          bottom - (bottom - top) * normalized;

      canvas.drawCircle(
        Offset(x, y),
        4,
        pointPaint,
      );

      canvas.drawCircle(
        Offset(x, y),
        6,
        Paint()
          ..color = color.withOpacity(0.12)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.primaryData != primaryData ||
        oldDelegate.secondaryData != secondaryData ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.primaryColor != primaryColor;
  }
}