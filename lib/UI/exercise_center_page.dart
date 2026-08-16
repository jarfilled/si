import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class ExerciseCenterPage extends StatelessWidget {
const ExerciseCenterPage({Key? key}) : super(key: key);

static const Color primaryGreen = Color(0xFF42D2A7);
static const Color darkTeal = Color(0xFF145954);
static const Color bgColor = Color(0xFFF7F9F9);

static const List<Exercise> exercises = [
Exercise(
title: 'رفع خستگی چشم',
description: 'قانون ۲۰-۲۰-۲۰',
duration: '۳ دقیقه',
level: 'آسان',
icon: Icons.remove_red_eye_outlined,

// Replace this with the Supabase Storage URL.
videoUrl: 'https://rdlxrnnvebkmldqoedpf.supabase.co/storage/v1/object/sign/exercise-videos/eyes.mp4?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9jY2I1ZGRmNi1iMGE1LTRhMzQtYTg5MC1lZjhkMzJhYzhhOTUiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJleGVyY2lzZS12aWRlb3MvZXllcy5tcDQiLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzg2ODM4MzE2LCJleHAiOjE4MTgzNzQzMTZ9.z77RenIBcXE2caWZc6evWD0gerBXi6dtG_355AJiiOo',
),
Exercise(
title: 'کشش گردن و شانه',
description: 'کاهش درد و گرفتگی',
duration: '۵ دقیقه',
level: 'متوسط',
icon: Icons.self_improvement,

// Replace this with the Supabase Storage URL.
videoUrl: 'https://rdlxrnnvebkmldqoedpf.supabase.co/storage/v1/object/sign/exercise-videos/arms.mp4?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9jY2I1ZGRmNi1iMGE1LTRhMzQtYTg5MC1lZjhkMzJhYzhhOTUiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJleGVyY2lzZS12aWRlb3MvYXJtcy5tcDQiLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzg2ODM4Mjg2LCJleHAiOjE4MTgzNzQyODZ9.y1QhBSz9sJUzcesa59MZAL-7GUZeggtzzCffTnWH_Zs',
),
Exercise(
title: 'اصلاح قوز کمر',
description: 'تقویت عضلات پشت',
duration: '۱۰ دقیقه',
level: 'متوسط',
icon: Icons.accessibility_new,

// Replace this with the Supabase Storage URL.
videoUrl: 'https://rdlxrnnvebkmldqoedpf.supabase.co/storage/v1/object/sign/exercise-videos/neck-hunch.mp4?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9jY2I1ZGRmNi1iMGE1LTRhMzQtYTg5MC1lZjhkMzJhYzhhOTUiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJleGVyY2lzZS12aWRlb3MvbmVjay1odW5jaC5tcDQiLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzg2ODM4MzM2LCJleHAiOjE4MTgzNzQzMzZ9.M_kigaNKXoVFEOFqnnt4IhaCGXNEwHbp4MDlJ6IX0ko',
),
Exercise(
title: 'نرمش مچ دست',
description: 'پیشگیری از فشار و گرفتگی مچ',
duration: '۴ دقیقه',
level: 'آسان',
icon: Icons.back_hand_outlined,

// Replace this with the Supabase Storage URL.
videoUrl: 'https://rdlxrnnvebkmldqoedpf.supabase.co/storage/v1/object/sign/exercise-videos/wrist.mp4?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9jY2I1ZGRmNi1iMGE1LTRhMzQtYTg5MC1lZjhkMzJhYzhhOTUiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJleGVyY2lzZS12aWRlb3Mvd3Jpc3QubXA0Iiwic2NvcGUiOiJkb3dubG9hZCIsImlhdCI6MTc4NjgzODM1MywiZXhwIjoxODE4Mzc0MzUzfQ.RCtbOSUhzU2lwifCFET-w5RrBrEAyzMZ2nP-5eHIg0A',
),
];

@override
Widget build(BuildContext context) {
return Directionality(
textDirection: TextDirection.rtl,
child: Scaffold(
backgroundColor: bgColor,
appBar: AppBar(
backgroundColor: Colors.transparent,
elevation: 0,
scrolledUnderElevation: 0,
centerTitle: true,
title: const Text(
'مرکز تمرین',
style: TextStyle(
color: darkTeal,
fontWeight: FontWeight.bold,
fontSize: 20,
),
),
),
body: ListView(
padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
children: [
_buildMotivationalBanner(),
const SizedBox(height: 28),

const Text(
'تمرینات پیشنهادی',
style: TextStyle(
fontSize: 19,
fontWeight: FontWeight.bold,
color: darkTeal,
),
),

const SizedBox(height: 6),

Text(
'تمرینی متناسب با نیاز بدنتان انتخاب کنید',
style: TextStyle(
fontSize: 13,
color: Colors.grey.shade600,
),
),

const SizedBox(height: 16),

...exercises.map(
(exercise) => _buildExerciseCard(
context,
exercise,
),
),
],
),
),
);
}

Widget _buildMotivationalBanner() {
return Container(
padding: const EdgeInsets.all(20),
decoration: BoxDecoration(
color: primaryGreen.withOpacity(0.15),
borderRadius: BorderRadius.circular(20),
border: Border.all(
color: primaryGreen.withOpacity(0.3),
),
),
child: Row(
children: [
Container(
width: 54,
height: 54,
decoration: BoxDecoration(
color: primaryGreen.withOpacity(0.18),
shape: BoxShape.circle,
),
child: const Icon(
Icons.directions_run_rounded,
size: 30,
color: primaryGreen,
),
),

const SizedBox(width: 15),

const Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
'زمان یک استراحت کوتاه است!',
style: TextStyle(
color: darkTeal,
fontSize: 16,
fontWeight: FontWeight.bold,
),
),
SizedBox(height: 8),
Text(
'تنها چند دقیقه تمرین در روز می‌تواند تأثیر چشمگیری روی سلامت شما بگذارد.',
style: TextStyle(
color: darkTeal,
fontSize: 13,
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

Widget _buildExerciseCard(
BuildContext context,
Exercise exercise,
) {
return Container(
margin: const EdgeInsets.only(bottom: 15),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(18),
boxShadow: [
BoxShadow(
color: Colors.black.withOpacity(0.035),
blurRadius: 12,
offset: const Offset(0, 5),
),
],
),
child: Material(
color: Colors.transparent,
borderRadius: BorderRadius.circular(18),
child: InkWell(
borderRadius: BorderRadius.circular(18),
onTap: () {
Navigator.of(context).push(
MaterialPageRoute(
builder: (_) => ExerciseVideoPage(
exercise: exercise,
),
),
);
},
child: Padding(
padding: const EdgeInsets.all(15),
child: Row(
children: [
// Exercise thumbnail / icon.
Container(
width: 64,
height: 64,
decoration: BoxDecoration(
color: bgColor,
borderRadius: BorderRadius.circular(14),
),
child: Stack(
alignment: Alignment.center,
children: [
Icon(
exercise.icon,
color: darkTeal,
size: 30,
),

Positioned(
bottom: 4,
right: 4,
child: Container(
width: 23,
height: 23,
decoration: const BoxDecoration(
color: primaryGreen,
shape: BoxShape.circle,
),
child: const Icon(
Icons.play_arrow_rounded,
color: Colors.white,
size: 16,
),
),
),
],
),
),

const SizedBox(width: 15),

Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
exercise.title,
style: const TextStyle(
fontWeight: FontWeight.bold,
fontSize: 15,
color: darkTeal,
),
),

const SizedBox(height: 4),

Text(
exercise.description,
style: TextStyle(
fontSize: 12,
color: Colors.grey.shade600,
),
),

const SizedBox(height: 9),

Row(
children: [
const Icon(
Icons.timer_outlined,
size: 14,
color: primaryGreen,
),

const SizedBox(width: 4),

Text(
exercise.duration,
style: const TextStyle(
fontSize: 12,
color: primaryGreen,
fontWeight: FontWeight.bold,
),
),

const SizedBox(width: 15),

Icon(
Icons.bar_chart_rounded,
size: 14,
color: Colors.grey.shade500,
),

const SizedBox(width: 4),

Text(
exercise.level,
style: TextStyle(
fontSize: 12,
color: Colors.grey.shade600,
),
),
],
),
],
),
),

const SizedBox(width: 8),

Icon(
Icons.chevron_left_rounded,
color: Colors.grey.shade400,
),
],
),
),
),
),
);
}
}


// ---------------------------------------------------------------------------
// Exercise model
// ---------------------------------------------------------------------------

class Exercise {
final String title;
final String description;
final String duration;
final String level;
final IconData icon;
final String videoUrl;

const Exercise({
required this.title,
required this.description,
required this.duration,
required this.level,
required this.icon,
required this.videoUrl,
});
}


// ---------------------------------------------------------------------------
// Exercise video page
// ---------------------------------------------------------------------------

class ExerciseVideoPage extends StatefulWidget {
final Exercise exercise;

const ExerciseVideoPage({
Key? key,
required this.exercise,
}) : super(key: key);

@override
State<ExerciseVideoPage> createState() => _ExerciseVideoPageState();
}

class _ExerciseVideoPageState extends State<ExerciseVideoPage> {
VideoPlayerController? _videoPlayerController;
ChewieController? _chewieController;

bool _isLoading = true;
String? _error;

@override
void initState() {
super.initState();
_initializePlayer();
}

Future<void> _initializePlayer() async {
try {
final videoController = VideoPlayerController.networkUrl(
Uri.parse(widget.exercise.videoUrl),
);

_videoPlayerController = videoController;

await videoController.initialize();

if (!mounted) {
await videoController.dispose();
return;
}

_chewieController = ChewieController(
videoPlayerController: videoController,
autoPlay: false,
looping: false,
allowFullScreen: true,
allowMuting: true,
showControls: true,
materialProgressColors: ChewieProgressColors(
playedColor: ExerciseCenterPage.primaryGreen,
handleColor: ExerciseCenterPage.primaryGreen,
backgroundColor: Colors.grey.shade300,
bufferedColor: ExerciseCenterPage.primaryGreen.withOpacity(0.3),
),
placeholder: Container(
color: Colors.black,
child: const Center(
child: CircularProgressIndicator(
color: ExerciseCenterPage.primaryGreen,
),
),
),
errorBuilder: (context, errorMessage) {
return Center(
child: Padding(
padding: const EdgeInsets.all(20),
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
const Icon(
Icons.error_outline_rounded,
color: Colors.white,
size: 45,
),
const SizedBox(height: 12),
const Text(
'پخش ویدیو با مشکل مواجه شد',
textAlign: TextAlign.center,
style: TextStyle(
color: Colors.white,
fontWeight: FontWeight.bold,
),
),
const SizedBox(height: 6),
Text(
errorMessage,
textAlign: TextAlign.center,
style: const TextStyle(
color: Colors.white70,
fontSize: 12,
),
),
],
),
),
);
},
);

setState(() {
_isLoading = false;
});
} catch (e) {
if (!mounted) return;

setState(() {
_isLoading = false;
_error = e.toString();
});
}
}

@override
void dispose() {
_chewieController?.dispose();
_videoPlayerController?.dispose();
super.dispose();
}

@override
Widget build(BuildContext context) {
return Directionality(
textDirection: TextDirection.rtl,
child: Scaffold(
backgroundColor: ExerciseCenterPage.bgColor,
appBar: AppBar(
backgroundColor: Colors.transparent,
elevation: 0,
scrolledUnderElevation: 0,
centerTitle: true,
title: Text(
widget.exercise.title,
style: const TextStyle(
color: ExerciseCenterPage.darkTeal,
fontWeight: FontWeight.bold,
fontSize: 18,
),
),
iconTheme: const IconThemeData(
color: ExerciseCenterPage.darkTeal,
),
),
body: ListView(
padding: const EdgeInsets.only(bottom: 30),
children: [
_buildVideo(),

Padding(
padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
widget.exercise.title,
style: const TextStyle(
fontSize: 22,
fontWeight: FontWeight.bold,
color: ExerciseCenterPage.darkTeal,
),
),

const SizedBox(height: 8),

Text(
widget.exercise.description,
style: TextStyle(
fontSize: 14,
color: Colors.grey.shade600,
),
),

const SizedBox(height: 18),

Row(
children: [
_buildInfoChip(
Icons.timer_outlined,
widget.exercise.duration,
),
const SizedBox(width: 10),
_buildInfoChip(
Icons.bar_chart_rounded,
widget.exercise.level,
),
],
),

const SizedBox(height: 25),

Container(
width: double.infinity,
padding: const EdgeInsets.all(18),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(18),
),
child: const Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
'نحوه انجام تمرین',
style: TextStyle(
fontSize: 16,
fontWeight: FontWeight.bold,
color: ExerciseCenterPage.darkTeal,
),
),
SizedBox(height: 10),
Text(
'ویدیو را با دقت مشاهده کنید و حرکات را به‌آرامی و بدون ایجاد درد انجام دهید. در صورت احساس ناراحتی، تمرین را متوقف کنید.',
style: TextStyle(
fontSize: 13,
height: 1.7,
color: Colors.black54,
),
),
],
),
),
],
),
),
],
),
),
);
}

Widget _buildVideo() {
if (_isLoading) {
return AspectRatio(
aspectRatio: 16 / 9,
child: Container(
color: Colors.black,
child: const Center(
child: CircularProgressIndicator(
color: ExerciseCenterPage.primaryGreen,
),
),
),
);
}

if (_error != null || _chewieController == null) {
return AspectRatio(
aspectRatio: 16 / 9,
child: Container(
color: Colors.black,
child: const Center(
child: Icon(
Icons.video_library_outlined,
color: Colors.white54,
size: 50,
),
),
),
);
}

return AspectRatio(
aspectRatio: _videoPlayerController?.value.aspectRatio ?? 16 / 9,
child: Chewie(
controller: _chewieController!,
),
);
}

Widget _buildInfoChip(
IconData icon,
String text,
) {
return Container(
padding: const EdgeInsets.symmetric(
horizontal: 12,
vertical: 8,
),
decoration: BoxDecoration(
color: ExerciseCenterPage.primaryGreen.withOpacity(0.12),
borderRadius: BorderRadius.circular(10),
),
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
const SizedBox(width: 1),
Icon(
icon,
size: 15,
color: ExerciseCenterPage.primaryGreen,
),
const SizedBox(width: 5),
Text(
text,
style: const TextStyle(
fontSize: 12,
color: ExerciseCenterPage.darkTeal,
fontWeight: FontWeight.w600,
),
),
],
),
);
}
}
