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
  static const line = Color(0xFFE8EFEC);
  static const mint = Color(0xFFE8F8F1);

  static const exercises = <Exercise>[
    Exercise(
      title: 'رفع خستگی چشم',
      description: 'حرکات ساده برای کاهش خستگی چشم و فشار ناشی از صفحه.',
      duration: '۳ دقیقه',
      level: 'آسان',
      icon: Icons.remove_red_eye_outlined,
      videoUrl:
      'https://rdlxrnnvebkmldqoedpf.supabase.co/storage/v1/object/sign/exercise-videos/eyes.mp4?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9jY2I1ZGRmNi1iMGE1LTRhMzQtYTg5MC1lZjhkMzJhYzhhOTUiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJleGVyY2lzZS12aWRlb3MvZXllcy5tcDQiLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzg3MDA0ODYyLCJleHAiOjE4MTg1NDA4NjJ9.dsQUrE9tDNOXPE1TfsHzAB74g4J86ZJELWjqQGbM9nQ',
      category: 'چشم',
    ),

    Exercise(
      title: 'استراحت و حرکت چشم',
      description: 'تمرین‌هایی برای کاهش فشار چشم هنگام استفاده طولانی از صفحه.',
      duration: '۳ دقیقه',
      level: 'آسان',
      icon: Icons.visibility_rounded,
      videoUrl:
      'https://rdlxrnnvebkmldqoedpf.supabase.co/storage/v1/object/sign/exercise-videos/eyes2.mp4?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9jY2I1ZGRmNi1iMGE1LTRhMzQtYTg5MC1lZjhkMzJhYzhhOTUiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJleGVyY2lzZS12aWRlb3MvZXllczIubXA0Iiwic2NvcGUiOiJkb3dubG9hZCIsImlhdCI6MTc4NzAwNDg3MiwiZXhwIjoxODE4NTQwODcyfQ.RD0a37mRmr0lRj6SnN0zz11jrF-g7kcKNoxULRiqekA',
      category: 'چشم',
    ),

    Exercise(
      title: 'کشش دست و بازو',
      description: 'کشش عضلات دست و بازو پس از استفاده طولانی از گوشی.',
      duration: '۵ دقیقه',
      level: 'آسان',
      icon: Icons.back_hand_rounded,
      videoUrl:
      'https://rdlxrnnvebkmldqoedpf.supabase.co/storage/v1/object/sign/exercise-videos/arms.mp4?token=eyJraWQiOiJjY2I1ZGRmNi1iMGE1LTRhMzQtYTg5MC1lZjhkMzJhYzhhOTUiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJleGVyY2lzZS12aWRlb3MvYXJtcy5tcDQiLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzg4MjQ3NzA0LCJleHAiOjE4MTk3ODM3MDR9.mZLV0k5ay2z_e-3_bPP1mjHm-099BmmqEDGoQkUO-QY',
      category: 'دست و بازو',
    ),

    Exercise(
      title: 'اصلاح قوز کمر',
      description: 'حرکات کششی و تقویتی برای کاهش فشار و گرفتگی پشت.',
      duration: '۱۰ دقیقه',
      level: 'متوسط',
      icon: Icons.accessibility_new_rounded,
      videoUrl:
      'https://rdlxrnnvebkmldqoedpf.supabase.co/storage/v1/object/sign/exercise-videos/neck-hunch.mp4?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9jY2I1ZGRmNi1iMGE1LTRhMzQtYTg5MC1lZjhkMzJhYzhhOTUiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJleGVyY2lzZS12aWRlb3MvbmVjay1odW5jaC5tcDQiLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzg3MDA0ODg0LCJleHAiOjE4MTg1NDA4ODR9.S9pePQDHam5hFOo6LjQ9Dxd1yasqBZTo-DzTOZZmk2c',
      category: 'کمر و گردن',
    ),

    Exercise(
      title: 'کشش کف دست',
      description: 'حرکات ساده برای کاهش تنش و خستگی عضلات کف دست.',
      duration: '۳ دقیقه',
      level: 'آسان',
      icon: Icons.pan_tool_outlined,
      videoUrl:
      'https://rdlxrnnvebkmldqoedpf.supabase.co/storage/v1/object/sign/exercise-videos/palms.mp4?token=eyJraWQiOiJjY2I1ZGRmNi1iMGE1LTRhMzQtYTg5MC1lZjhkMzJhYzhhOTUiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJleGVyY2lzZS12aWRlb3MvcGFsbXMubXA0Iiwic2NvcGUiOiJkb3dubG9hZCIsImlhdCI6MTc4ODI1MDMzMiwiZXhwIjoxODE5Nzg2MzMyfQ.Tz_bZAJPjO8l56Qq75hYG5Xds8_Q5PZU_jyrJYQzx10',
      category: 'دست و مچ',
    ),

    Exercise(
      title: 'نرمش مچ دست',
      description: 'کاهش فشار و گرفتگی مچ در اثر استفاده طولانی از گوشی.',
      duration: '۴ دقیقه',
      level: 'آسان',
      icon: Icons.back_hand_outlined,
      videoUrl:
      'https://rdlxrnnvebkmldqoedpf.supabase.co/storage/v1/object/sign/exercise-videos/wrist.mp4?token=eyJraWQiOiJjY2I1ZGRmNi1iMGE1LTRhMzQtYTg5MC1lZjhkMzJhYzhhOTUiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJleGVyY2lzZS12aWRlb3Mvd3Jpc3QubXA0Iiwic2NvcGUiOiJkb3dubG9hZCIsImlhdCI6MTc4ODI1MDM2MiwiZXhwIjoxODE5Nzg2MzYyfQ.tZbHtXgExobbzM4Wq4lxlyWZFgEAyRp5qAgJ8wivFc8',
      category: 'دست و مچ',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
            children: [
              const Text(
                'مرکز تمرین',
                style: TextStyle(
                  color: text,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'تمرین کوتاه را بر اساس نیاز بدنت انتخاب کن.',
                style: TextStyle(
                  color: subtext,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 14),

              Container(
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [green, teal],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.directions_run_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'استراحت کوتاه هم تمرین است',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'چند دقیقه حرکت بین دوره‌های استفاده از صفحه می‌تواند به حفظ وضعیت بدن کمک کند.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'تمرین‌ها',
                style: TextStyle(
                  color: text,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: 10),

              ...exercises.map(
                    (exercise) => _ExerciseTile(
                  exercise: exercise,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Exercise {
  final String title;
  final String description;
  final String duration;
  final String level;
  final IconData icon;
  final String videoUrl;
  final String category;

  const Exercise({
    required this.title,
    required this.description,
    required this.duration,
    required this.level,
    required this.icon,
    required this.videoUrl,
    required this.category,
  });
}

class _ExerciseTile extends StatelessWidget {
  final Exercise exercise;

  const _ExerciseTile({
    required this.exercise,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ExerciseCenterPage.line,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExerciseVideoPage(
                exercise: exercise,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: ExerciseCenterPage.bg,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      exercise.icon,
                      color: ExerciseCenterPage.text,
                      size: 28,
                    ),
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        width: 21,
                        height: 21,
                        decoration: const BoxDecoration(
                          color: ExerciseCenterPage.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ExerciseCenterPage.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      exercise.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ExerciseCenterPage.subtext,
                        fontSize: 9,
                        height: 1.35,
                      ),
                    ),

                    const SizedBox(height: 7),

                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _InfoBadge(
                          icon: Icons.timer_outlined,
                          text: exercise.duration,
                          color: ExerciseCenterPage.green,
                        ),
                        _InfoBadge(
                          icon: Icons.bar_chart_rounded,
                          text: exercise.level,
                          color: ExerciseCenterPage.teal,
                        ),
                        Text(
                          exercise.category,
                          style: const TextStyle(
                            color: ExerciseCenterPage.subtext,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 5),

              const Icon(
                Icons.chevron_left_rounded,
                color: ExerciseCenterPage.subtext,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoBadge({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: color,
          size: 13,
        ),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 8,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class ExerciseVideoPage extends StatefulWidget {
  final Exercise exercise;

  const ExerciseVideoPage({
    super.key,
    required this.exercise,
  });

  @override
  State<ExerciseVideoPage> createState() =>
      _ExerciseVideoPageState();
}

class _ExerciseVideoPageState
    extends State<ExerciseVideoPage> {
  VideoPlayerController? _controller;

  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    try {
      final player = VideoPlayerController.networkUrl(
        Uri.parse(widget.exercise.videoUrl),
      );

      await player.initialize();

      if (!mounted) {
        await player.dispose();
        return;
      }

      player.addListener(_videoListener);

      setState(() {
        _controller = player;
        _loading = false;
      });
    } catch (error, stackTrace) {
      debugPrint(
        '[ExerciseVideo] Failed to load: $error',
      );
      debugPrint('$stackTrace');

      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }
  void _videoListener() {
    if (!mounted || _controller == null) return;

    // Rebuild when play/pause/end state changes.
    setState(() {});
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      // Restart automatically when the video reached its end.
      if (controller.value.position >=
          controller.value.duration) {
        await controller.seekTo(Duration.zero);
      }

      await controller.play();
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _restartVideo() async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    await controller.seekTo(Duration.zero);
    await controller.play();

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: ExerciseCenterPage.bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          title: Text(
            widget.exercise.title,
            style: const TextStyle(
              color: ExerciseCenterPage.text,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          iconTheme: const IconThemeData(
            color: ExerciseCenterPage.text,
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            16,
            8,
            16,
            30,
          ),
          children: [
            _buildVideoPlayer(controller),

            const SizedBox(height: 16),

            _buildExerciseInfo(),

            const SizedBox(height: 12),

            _buildInstructionCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer(
      VideoPlayerController? controller,
      ) {
    final initialized =
        controller?.value.isInitialized == true;

    final aspectRatio =
    initialized
        ? controller!.value.aspectRatio
        : 16 / 9;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius:
        BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: aspectRatio > 0
            ? aspectRatio
            : 16 / 9,
        child: _loading
            ? const Center(
          child:
          CircularProgressIndicator(
            color:
            ExerciseCenterPage.green,
          ),
        )
            : _error != null
            ? _buildVideoError()
            : controller == null
            ? const Center(
          child: Text(
            'ویدیوی تمرین در دسترس نیست.',
            style: TextStyle(
              color: Colors.white,
              fontWeight:
              FontWeight.w800,
            ),
          ),
        )
            : _buildLoadedVideo(
          controller,
        ),
      ),
    );
  }

  Widget _buildLoadedVideo(
      VideoPlayerController controller,
      ) {
    final value = controller.value;

    return Stack(
      fit: StackFit.expand,
      children: [
        VideoPlayer(controller),

        AnimatedOpacity(
          duration:
          const Duration(milliseconds: 150),
          opacity:
          value.isPlaying ? 0.0 : 1.0,
          child: Center(
            child: IconButton(
              onPressed: _togglePlayback,
              iconSize: 58,
              style: IconButton.styleFrom(
                backgroundColor:
                Colors.black54,
              ),
              icon: Icon(
                value.position >= value.duration
                    ? Icons.replay_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
              ),
            ),
          ),
        ),

        if (value.isPlaying)
          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius:
                BorderRadius.circular(14),
              ),
              child: IconButton(
                onPressed: _togglePlayback,
                icon: const Icon(
                  Icons.pause_rounded,
                  color: Colors.white,
                ),
              ),
            ),
          ),

        Positioned(
          bottom: 12,
          right: 12,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius:
              BorderRadius.circular(14),
            ),
            child: IconButton(
              onPressed: _restartVideo,
              icon: const Icon(
                Icons.replay_rounded,
                color: Colors.white,
              ),
            ),
          ),
        ),

        if (value.isInitialized)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              padding: EdgeInsets.zero,
              colors:
              const VideoProgressColors(
                playedColor:
                ExerciseCenterPage.green,
                bufferedColor:
                Color(0x66FFFFFF),
                backgroundColor:
                Color(0x33000000),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVideoError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            const Icon(
              Icons.video_library_outlined,
              color: Colors.white70,
              size: 38,
            ),
            const SizedBox(height: 10),
            const Text(
              'ویدیوی تمرین در دسترس نیست.',
              textAlign:
              TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight:
                FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'لطفاً اتصال اینترنت خود را بررسی کنید.',
              textAlign:
              TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseInfo() {
    return Container(
      padding:
      const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(20),
        border: Border.all(
          color:
          ExerciseCenterPage.line,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            widget.exercise.title,
            style: const TextStyle(
              color:
              ExerciseCenterPage.text,
              fontSize: 18,
              fontWeight:
              FontWeight.w900,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            widget.exercise.description,
            style: const TextStyle(
              color:
              ExerciseCenterPage.subtext,
              fontSize: 11,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 13),

          Wrap(
            spacing: 14,
            runSpacing: 7,
            children: [
              _detail(
                Icons.timer_outlined,
                widget.exercise.duration,
                ExerciseCenterPage.green,
              ),
              _detail(
                Icons.bar_chart_rounded,
                widget.exercise.level,
                ExerciseCenterPage.teal,
              ),
              _detail(
                Icons.category_outlined,
                widget.exercise.category,
                ExerciseCenterPage.green,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detail(
      IconData icon,
      String value,
      Color color,
      ) {
    return Row(
      mainAxisSize:
      MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: color,
          size: 16,
        ),
        const SizedBox(width: 5),
        Text(
          value,
          style: const TextStyle(
            color:
            ExerciseCenterPage.text,
            fontSize: 10,
            fontWeight:
            FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionCard() {
    return Container(
      padding:
      const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color:
        ExerciseCenterPage.mint,
        borderRadius:
        BorderRadius.circular(18),
      ),
      child: const Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color:
            ExerciseCenterPage.green,
            size: 21,
          ),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'تمرین را با حرکت کنترل‌شده انجام بده و اگر درد یا ناراحتی غیرعادی داشتی، تمرین را متوقف کن.',
              style: TextStyle(
                color:
                ExerciseCenterPage.text,
                fontSize: 10,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}