import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExerciseCenterPage extends StatelessWidget {
  const ExerciseCenterPage({super.key});

  static const green = Color(0xFF42D2A7);
  static const teal = Color(0xFF45C4D0);
  static const bg = Color(0xFFF4F9F7);
  static const text = Color(0xFF263B37);
  static const subtext = Color(0xFF7D8D89);
  static const mint = Color(0xFFE8F8F1);

  static const exercises = <Exercise>[
    Exercise('رفع خستگی چشم', 'قانون ۲۰-۲۰-۲۰', '۳ دقیقه', 'آسان', Icons.remove_red_eye_outlined, 'eyes.mp4'),
    Exercise('کشش گردن و شانه', 'کاهش گرفتگی گردن و شانه', '۵ دقیقه', 'متوسط', Icons.self_improvement_rounded, 'arms.mp4'),
    Exercise('اصلاح قوز کمر', 'تقویت عضلات پشت', '۱۰ دقیقه', 'متوسط', Icons.accessibility_new_rounded, 'neck-hunch.mp4'),
    Exercise('نرمش مچ دست', 'کاهش فشار و گرفتگی مچ', '۴ دقیقه', 'آسان', Icons.back_hand_outlined, 'wrist.mp4'),
  ];

  @override
  Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl, child: Scaffold(backgroundColor: bg, body: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 30), children: [
    const Text('مرکز تمرین', style: TextStyle(color: text, fontSize: 23, fontWeight: FontWeight.w900)),
    const SizedBox(height: 4),
    const Text('تمرین کوتاه را بر اساس نیاز بدنت انتخاب کن.', style: TextStyle(color: subtext, fontSize: 10)),
    const SizedBox(height: 14),
    Container(padding: const EdgeInsets.all(17), decoration: BoxDecoration(gradient: const LinearGradient(colors: [green, teal]), borderRadius: BorderRadius.circular(22)), child: const Row(children: [Icon(Icons.directions_run_rounded, color: Colors.white, size: 30), SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('استراحت کوتاه هم تمرین است', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)), SizedBox(height: 4), Text('چند دقیقه حرکت بین دوره‌های استفاده از صفحه می‌تواند به حفظ وضعیت بدن کمک کند.', style: TextStyle(color: Colors.white70, fontSize: 10, height: 1.5))]))])),
    const SizedBox(height: 20),
    const Text('تمرین‌ها', style: TextStyle(color: text, fontSize: 16, fontWeight: FontWeight.w900)),
    const SizedBox(height: 10),
    ...exercises.map((e) => _ExerciseTile(exercise: e)),
  ]))));
}

class Exercise {
  final String title;
  final String description;
  final String duration;
  final String level;
  final IconData icon;
  final String storagePath;
  const Exercise(this.title, this.description, this.duration, this.level, this.icon, this.storagePath);
}

class _ExerciseTile extends StatelessWidget {
  final Exercise exercise;
  const _ExerciseTile({required this.exercise});

  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 9), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE8EFEC))), child: InkWell(borderRadius: BorderRadius.circular(20), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExerciseVideoPage(exercise: exercise))), child: Padding(padding: const EdgeInsets.all(13), child: Row(children: [Container(width: 55, height: 55, decoration: BoxDecoration(color: const Color(0xFFF4F9F7), borderRadius: BorderRadius.circular(16)), child: Stack(alignment: Alignment.center, children: [Icon(exercise.icon, color: ExerciseCenterPage.text, size: 27), Positioned(bottom: 2, right: 2, child: Container(width: 20, height: 20, decoration: const BoxDecoration(color: ExerciseCenterPage.green, shape: BoxShape.circle), child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 13)))])), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(exercise.title, style: const TextStyle(color: ExerciseCenterPage.text, fontSize: 12, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(exercise.description, style: const TextStyle(color: ExerciseCenterPage.subtext, fontSize: 9)), const SizedBox(height: 7), Row(children: [const Icon(Icons.timer_outlined, color: ExerciseCenterPage.green, size: 13), const SizedBox(width: 3), Text(exercise.duration, style: const TextStyle(color: ExerciseCenterPage.green, fontSize: 9, fontWeight: FontWeight.w800)), const SizedBox(width: 10), Text(exercise.level, style: const TextStyle(color: ExerciseCenterPage.subtext, fontSize: 9))]))]), const Icon(Icons.chevron_left_rounded, color: ExerciseCenterPage.subtext)]))));
}

class ExerciseVideoPage extends StatefulWidget {
  final Exercise exercise;
  const ExerciseVideoPage({super.key, required this.exercise});
  @override
  State<ExerciseVideoPage> createState() => _ExerciseVideoPageState();
}

class _ExerciseVideoPageState extends State<ExerciseVideoPage> {
  VideoPlayerController? controller;
  String? error;
  bool loading = true;

  @override
  void initState() { super.initState(); _loadVideo(); }

  Future<void> _loadVideo() async {
    try {
      final url = await Supabase.instance.client.storage.from('exercise-videos').createSignedUrl(widget.exercise.storagePath, 3600);
      final player = VideoPlayerController.networkUrl(Uri.parse(url));
      await player.initialize();
      if (!mounted) { await player.dispose(); return; }
      setState(() { controller = player; loading = false; });
    } catch (e) {
      if (mounted) setState(() { loading = false; error = e.toString(); });
    }
  }

  @override
  void dispose() { controller?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final player = controller;
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(backgroundColor: ExerciseCenterPage.bg, appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, centerTitle: true, title: Text(widget.exercise.title, style: const TextStyle(color: ExerciseCenterPage.text, fontSize: 16, fontWeight: FontWeight.w900)), iconTheme: const IconThemeData(color: ExerciseCenterPage.text)), body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
      AspectRatio(aspectRatio: player?.value.aspectRatio ?? 16 / 9, child: Container(decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)), clipBehavior: Clip.antiAlias, child: loading ? const Center(child: CircularProgressIndicator(color: ExerciseCenterPage.green)) : error != null ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('ویدیوی تمرین در دسترس نیست.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)))) : player == null ? const SizedBox.shrink() : Stack(alignment: Alignment.center, children: [VideoPlayer(player), IconButton(onPressed: () => setState(() { player.value.isPlaying ? player.pause() : player.play(); }), iconSize: 54, style: IconButton.styleFrom(backgroundColor: Colors.black45), icon: Icon(player.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white))]))),
      const SizedBox(height: 16),
      Container(padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE8EFEC))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.exercise.title, style: const TextStyle(color: ExerciseCenterPage.text, fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 6), Text(widget.exercise.description, style: const TextStyle(color: ExerciseCenterPage.subtext, fontSize: 11, height: 1.5)), const SizedBox(height: 12), Row(children: [const Icon(Icons.timer_outlined, color: ExerciseCenterPage.green, size: 16), const SizedBox(width: 5), Text(widget.exercise.duration, style: const TextStyle(color: ExerciseCenterPage.text, fontSize: 10, fontWeight: FontWeight.w800)), const SizedBox(width: 15), const Icon(Icons.bar_chart_rounded, color: ExerciseCenterPage.teal, size: 16), const SizedBox(width: 5), Text(widget.exercise.level, style: const TextStyle(color: ExerciseCenterPage.text, fontSize: 10, fontWeight: FontWeight.w800))])]))
    ]));
  }
}
