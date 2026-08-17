import 'package:flutter/material.dart';

class WomensHealthPage extends StatefulWidget {
  const WomensHealthPage({super.key});

  @override
  State<WomensHealthPage> createState() => _WomensHealthPageState();
}

class _WomensHealthPageState extends State<WomensHealthPage> {
  static const green = Color(0xFF42D2A7);
  static const teal = Color(0xFF45C4D0);
  static const darkTeal = Color(0xFF145954);
  static const bg = Color(0xFFF7F9F9);
  static const pink = Color(0xFFFFA5B7);
  static const lightPink = Color(0xFFFFEEF2);
  static const muted = Color(0xFF71807F);
  static const line = Color(0xFFE8EFEC);

  int pain = 5;
  int mood = 3;
  int energy = 3;
  bool heat = false;
  bool hydration = false;
  bool movement = false;
  bool socialReminder = false;
  final TextEditingController noteController = TextEditingController();

  final List<double> painHistory = [3, 4, 4, 6, 5, 7, 5];
  final List<double> moodHistory = [4, 3, 3, 2, 3, 2, 3];
  final List<double> energyHistory = [4, 4, 3, 2, 2, 3, 3];

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: const Text('سلامت و قاعدگی', style: TextStyle(color: darkTeal, fontWeight: FontWeight.w900)),
          iconTheme: const IconThemeData(color: darkTeal),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = constraints.maxWidth >= 700;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(horizontal ? 28 : 16, 4, horizontal ? 28 : 16, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _cycleOverview(),
                      const SizedBox(height: 14),
                      _statusCard(),
                      const SizedBox(height: 20),
                      _section('وضعیت امروز'),
                      const SizedBox(height: 10),
                      if (horizontal)
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(child: _painCard()),
                          const SizedBox(width: 12),
                          Expanded(child: _moodEnergyCard()),
                        ])
                      else ...[
                        _painCard(),
                        const SizedBox(height: 12),
                        _moodEnergyCard(),
                      ],
                      const SizedBox(height: 20),
                      _section('روند علائم'),
                      const SizedBox(height: 10),
                      if (horizontal)
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(child: _chartCard('روند درد', '۷ روز گذشته', painHistory, 10, pink)),
                          const SizedBox(width: 12),
                          Expanded(child: _chartCard('خلق‌وخو و انرژی', 'مقایسه هفت روز گذشته', moodHistory, 5, green, secondary: energyHistory)),
                        ])
                      else ...[
                        _chartCard('روند درد', '۷ روز گذشته', painHistory, 10, pink),
                        const SizedBox(height: 12),
                        _chartCard('خلق‌وخو و انرژی', 'مقایسه هفت روز گذشته', moodHistory, 5, green, secondary: energyHistory),
                      ],
                      const SizedBox(height: 20),
                      _section('مراقبت امروز'),
                      const SizedBox(height: 10),
                      _careCard(),
                      const SizedBox(height: 12),
                      _socialCard(),
                      const SizedBox(height: 20),
                      _dailyLog(),
                      const SizedBox(height: 12),
                      _safetyCard(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _section(String title) => Text(title, style: const TextStyle(color: darkTeal, fontSize: 18, fontWeight: FontWeight.w900));

  Widget _card({required Widget child, EdgeInsets padding = const EdgeInsets.all(16)}) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: line),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 16, offset: Offset(0, 5))],
      ),
      child: child,
    );
  }

  Widget _cycleOverview() {
    return _card(
      padding: const EdgeInsets.all(18),
      child: Column(children: [
        Row(children: [
          _iconBox(Icons.calendar_month_rounded, pink, lightPink),
          const SizedBox(width: 11),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('چرخه فعلی', style: TextStyle(color: muted, fontSize: 12)),
            SizedBox(height: 3),
            Text('روز ۱۴ از حدود ۲۸ روز', style: TextStyle(color: darkTeal, fontSize: 15, fontWeight: FontWeight.w900)),
          ])),
          Flexible(child: Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: lightPink, borderRadius: BorderRadius.circular(11)), child: const Text('فاز میانی', style: TextStyle(color: pink, fontSize: 10, fontWeight: FontWeight.w900)))),
        ]),
        const SizedBox(height: 18),
        ClipRRect(borderRadius: BorderRadius.circular(20), child: const LinearProgressIndicator(value: .5, minHeight: 9, backgroundColor: bg, valueColor: AlwaysStoppedAnimation(pink))),
        const SizedBox(height: 9),
        const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('شروع چرخه', style: TextStyle(color: muted, fontSize: 10)),
          Text('روز ۱۴', style: TextStyle(color: pink, fontSize: 10, fontWeight: FontWeight.w900)),
          Text('چرخه بعدی', style: TextStyle(color: muted, fontSize: 10)),
        ]),
      ]),
    );
  }

  Widget _statusCard() {
    final significant = pain >= 7 || mood <= 2;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [pink.withValues(alpha: .18), green.withValues(alpha: .08)], begin: Alignment.topRight, end: Alignment.bottomLeft),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: pink.withValues(alpha: .22)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 46, height: 46, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .85), shape: BoxShape.circle), child: Icon(significant ? Icons.favorite_border_rounded : Icons.spa_rounded, color: pink, size: 25)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(significant ? 'امروز کمی بیشتر مراقب خودت باش' : 'وضعیت امروزت ثبت شد', style: const TextStyle(color: darkTeal, fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text(significant ? 'علائم ثبت‌شده نشان می‌دهند بهتر است امروز فشار کمتری به خودت وارد کنی.' : 'ثبت روزانه به سی کمک می‌کند الگوی علائم را در طول زمان بهتر نشان دهد.', style: const TextStyle(color: muted, fontSize: 11, height: 1.55)),
        ])),
      ]),
    );
  }

  Widget _painCard() {
    return _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _metricHeader(Icons.monitor_heart_outlined, pink, lightPink, 'میزان درد امروز', 'شدت درد را از ۰ تا ۱۰ مشخص کن', '$pain/10'),
      const SizedBox(height: 13),
      SliderTheme(data: SliderThemeData(activeTrackColor: _painColor(pain), inactiveTrackColor: bg, thumbColor: _painColor(pain), overlayColor: _painColor(pain).withValues(alpha: .12), trackHeight: 7), child: Slider(min: 0, max: 10, divisions: 10, value: pain.toDouble(), onChanged: (v) => setState(() => pain = v.round()))),
      const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('بدون درد', style: TextStyle(color: muted, fontSize: 9)), Text('متوسط', style: TextStyle(color: muted, fontSize: 9)), Text('شدید', style: TextStyle(color: muted, fontSize: 9))]),
      const SizedBox(height: 12),
      Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: _painColor(pain).withValues(alpha: .08), borderRadius: BorderRadius.circular(13)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(pain >= 8 ? Icons.warning_amber_rounded : Icons.favorite_border_rounded, color: _painColor(pain), size: 21), const SizedBox(width: 8), Expanded(child: Text(_painMessage(), style: const TextStyle(color: muted, fontSize: 10, height: 1.5)))])),
    ]));
  }

  String _painMessage() {
    if (pain <= 2) return 'درد خفیف است؛ مراقبت معمول و استراحت کوتاه می‌تواند کافی باشد.';
    if (pain <= 5) return 'اگر لازم است، شدت فعالیت را کمتر کن و از مراقبت‌های ساده استفاده کن.';
    if (pain <= 7) return 'اگر درد فعالیت روزانه را مختل می‌کند، امروز فشار کمتری به خودت وارد کن.';
    return 'اگر این درد غیرمعمول، ادامه‌دار یا مختل‌کننده فعالیت روزانه است، با متخصص سلامت مشورت کن.';
  }

  Color _painColor(int value) {
    if (value <= 2) return green;
    if (value <= 5) return Colors.orangeAccent;
    if (value <= 7) return Colors.deepOrangeAccent;
    return Colors.redAccent;
  }

  Widget _moodEnergyCard() {
    return _card(child: Column(children: [
      _slider('خلق‌وخو', 'امروز از نظر روحی چطوری؟', Icons.mood_rounded, Colors.orangeAccent, mood, (v) => mood = v),
      const SizedBox(height: 14),
      _slider('انرژی', 'چقدر انرژی برای فعالیت داری؟', Icons.bolt_rounded, green, energy, (v) => energy = v),
    ]));
  }

  Widget _slider(String title, String subtitle, IconData icon, Color color, int value, ValueChanged<int> change) {
    return Column(children: [
      _metricHeader(icon, color, color.withValues(alpha: .10), title, subtitle, '$value/5'),
      SliderTheme(data: SliderThemeData(activeTrackColor: color, inactiveTrackColor: bg, thumbColor: color, trackHeight: 6), child: Slider(min: 1, max: 5, divisions: 4, value: value.toDouble(), onChanged: (v) => setState(() => change(v.round())))),
    ]);
  }

  Widget _metricHeader(IconData icon, Color color, Color iconBg, String title, String subtitle, String value) {
    return Row(children: [
      _iconBox(icon, color, iconBg),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: darkTeal, fontSize: 13, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: muted, fontSize: 10))])),
      Text(value, style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w900)),
    ]);
  }

  Widget _chartCard(String title, String subtitle, List<double> data, double max, Color color, {List<double>? secondary}) {
    return _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [_iconBox(Icons.insights_rounded, color, color.withValues(alpha: .10)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: darkTeal, fontSize: 13, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: muted, fontSize: 10))]))]),
      const SizedBox(height: 12),
      SizedBox(height: 130, width: double.infinity, child: CustomPaint(painter: _LineChartPainter(data, secondary, max, color, secondary == null ? null : pink, bg))),
      const SizedBox(height: 5),
      const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('۷ روز پیش', style: TextStyle(color: muted, fontSize: 9)), Text('امروز', style: TextStyle(color: muted, fontSize: 9))]),
      if (secondary != null) ...[const SizedBox(height: 8), Row(children: [_legend(green, 'خلق‌وخو'), const SizedBox(width: 14), _legend(pink, 'انرژی')])],
    ]));
  }

  Widget _legend(Color color, String label) => Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 5), Text(label, style: const TextStyle(color: muted, fontSize: 9))]);

  Widget _careCard() {
    return _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('چند گزینه ساده برای امتحان کردن', style: TextStyle(color: darkTeal, fontSize: 13, fontWeight: FontWeight.w900)),
      const SizedBox(height: 4),
      const Text('مواردی را که امتحان کرده‌ای علامت بزن تا ثبت روزانه‌ات معنادارتر شود.', style: TextStyle(color: muted, fontSize: 10, height: 1.5)),
      const SizedBox(height: 11),
      _careTile(Icons.local_fire_department_outlined, 'گرمای ملایم', 'برای گرفتگی‌ها می‌تواند آرام‌کننده باشد.', pink, heat, () => setState(() => heat = !heat)),
      _careTile(Icons.water_drop_outlined, 'آب کافی', 'مایعات کافی و وعده‌های منظم را فراموش نکن.', teal, hydration, () => setState(() => hydration = !hydration)),
      _careTile(Icons.directions_walk_rounded, 'حرکت سبک', 'اگر بدنت اجازه می‌دهد، پیاده‌روی یا کشش سبک.', Colors.orangeAccent, movement, () => setState(() => movement = !movement)),
    ]));
  }

  Widget _careTile(IconData icon, String title, String description, Color color, bool selected, VoidCallback onTap) {
    return Padding(padding: const EdgeInsets.only(bottom: 7), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(13), child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: selected ? color.withValues(alpha: .08) : bg, borderRadius: BorderRadius.circular(13), border: Border.all(color: selected ? color.withValues(alpha: .28) : Colors.transparent)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [_iconBox(icon, color, color.withValues(alpha: .10), size: 38, iconSize: 19), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: darkTeal, fontSize: 11, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(description, style: const TextStyle(color: muted, fontSize: 9, height: 1.4))])), Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined, color: selected ? color : Colors.grey, size: 20)]))));
  }

  Widget _socialCard() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(color: darkTeal, borderRadius: BorderRadius.circular(20)),
      child: LayoutBuilder(builder: (context, constraints) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .10), shape: BoxShape.circle), child: const Icon(Icons.groups_rounded, color: Colors.white, size: 22)), const SizedBox(width: 10), const Expanded(child: Text('یک ارتباط کوچک هم مراقبت از خود است', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)))]),
          const SizedBox(height: 8),
          Text('اگر چند روز است بیشتر تنها مانده‌ای، امروز می‌تواند فرصت خوبی برای یک تماس، دیدن یک دوست یا چند دقیقه بیرون رفتن باشد.', style: TextStyle(color: Colors.white.withValues(alpha: .78), fontSize: 10, height: 1.55)),
          const SizedBox(height: 10),
          Wrap(spacing: 7, runSpacing: 7, children: [
            _socialChip('با یک دوست تماس بگیر', Icons.phone_rounded),
            _socialChip('یک نفر را ببین', Icons.person_add_alt_rounded),
            _socialChip(socialReminder ? 'یادآوری روشن است' : 'برای امروز یادم بنداز', Icons.notifications_active_outlined),
          ]),
        ]);
      }),
    );
  }

  Widget _socialChip(String text, IconData icon) {
    return InkWell(onTap: text.contains('یادم') ? () => setState(() => socialReminder = !socialReminder) : null, borderRadius: BorderRadius.circular(11), child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .10), borderRadius: BorderRadius.circular(11)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: green, size: 15), const SizedBox(width: 5), Text(text, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700))])));
  }

  Widget _dailyLog() {
    return _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('یادداشت امروز', style: TextStyle(color: darkTeal, fontSize: 13, fontWeight: FontWeight.w900)),
      const SizedBox(height: 4),
      const Text('هر چیزی که در علائم امروز مهم بوده ثبت کن.', style: TextStyle(color: muted, fontSize: 10)),
      const SizedBox(height: 10),
      TextField(controller: noteController, maxLines: 3, textDirection: TextDirection.rtl, decoration: InputDecoration(hintText: 'مثلاً امروز گرفتگی بیشتری داشتم...', hintStyle: const TextStyle(color: Colors.grey, fontSize: 10), filled: true, fillColor: bg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide.none))),
      const SizedBox(height: 9),
      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => FocusScope.of(context).unfocus(), icon: const Icon(Icons.check_rounded, size: 17), label: const Text('ثبت اطلاعات امروز', style: TextStyle(fontWeight: FontWeight.w900)), style: FilledButton.styleFrom(backgroundColor: green, foregroundColor: darkTeal, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)))))
    ]));
  }

  Widget _safetyCard() => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.orangeAccent.withValues(alpha: .08), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.orangeAccent.withValues(alpha: .18))), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.info_outline_rounded, color: Colors.orangeAccent, size: 20), const SizedBox(width: 8), const Expanded(child: Text('اگر درد بسیار شدید یا غیرمعمول است، ناگهان بدتر شده یا فعالیت‌های روزانه را مختل می‌کند، بهتر است با پزشک یا متخصص سلامت مشورت شود.', style: TextStyle(color: muted, fontSize: 9, height: 1.6)))]));

  Widget _iconBox(IconData icon, Color color, Color background, {double size = 42, double iconSize = 21}) => Container(width: size, height: size, decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: iconSize));
}

class _LineChartPainter extends CustomPainter {
  final List<double> primary;
  final List<double>? secondary;
  final double maxValue;
  final Color primaryColor;
  final Color? secondaryColor;
  final Color gridColor;

  const _LineChartPainter(this.primary, this.secondary, this.maxValue, this.primaryColor, this.secondaryColor, this.gridColor);

  @override
  void paint(Canvas canvas, Size size) {
    if (primary.length < 2) return;
    final left = 8.0;
    final right = size.width - 8;
    final top = 8.0;
    final bottom = size.height - 8;
    final grid = Paint()..color = gridColor..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = top + (bottom - top) * i / 4;
      canvas.drawLine(Offset(left, y), Offset(right, y), grid);
    }
    _draw(canvas, primary, primaryColor, left, right, top, bottom);
    if (secondary != null && secondaryColor != null && secondary!.length > 1) _draw(canvas, secondary!, secondaryColor!, left, right, top, bottom);
  }

  void _draw(Canvas canvas, List<double> data, Color color, double left, double right, double top, double bottom) {
    final line = Paint()..color = color..strokeWidth = 2.6..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final point = Paint()..color = color;
    final path = Path();
    for (var i = 0; i < data.length; i++) {
      final x = left + (right - left) * i / (data.length - 1);
      final normalized = (data[i] / maxValue).clamp(0.0, 1.0);
      final y = bottom - (bottom - top) * normalized;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 3.3, point);
    }
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) => oldDelegate.primary != primary || oldDelegate.secondary != secondary || oldDelegate.maxValue != maxValue || oldDelegate.primaryColor != primaryColor || oldDelegate.secondaryColor != secondaryColor;
}
