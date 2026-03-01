import 'dart:async';
import 'dart:math';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Car Player',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF0A1020),
        fontFamily: 'Digital',
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
        ),
      ),
      home: const PlayerScreen(),
    );
  }
}

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final AudioPlayer _player = AudioPlayer();
  final OnAudioQuery _audioQuery = OnAudioQuery();

  List<SongModel> _songs = [];
  int _currentIndex = 0;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _requestPermission();
    final savedFolder = await _loadFolderPath();

    if (savedFolder != null) {
      await _loadFromFolder(savedFolder);
    } else {
      await _loadSongs();
    }
  }

  Future<void> _requestPermission() async {
    await Permission.storage.request();
    await Permission.audio.request();
  }

  Future<void> _loadSongs() async {
    final songs = await _audioQuery.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    setState(() => _songs = songs);

    if (_songs.isNotEmpty) {
      await _player.setAudioSource(AudioSource.uri(Uri.parse(_songs[0].uri!)));
    }
  }

  Future<void> _pickFolder() async {
    String? folder = await FilePicker.platform.getDirectoryPath();
    if (folder == null) return;

    await _saveFolderPath(folder);
    await _loadFromFolder(folder);

    if (_songs.isNotEmpty) {
      await _player.play();
      setState(() => _isPlaying = true);
    }
  }

  Future<void> _loadFromFolder(String folderPath) async {
    final dir = Directory(folderPath);
    if (!dir.existsSync()) return;

    final files = dir.listSync(recursive: true).where((f) =>
        f.path.endsWith('.mp3') ||
        f.path.endsWith('.wav') ||
        f.path.endsWith('.flac') ||
        f.path.endsWith('.aac') ||
        f.path.endsWith('.ogg')).toList();

    if (files.isEmpty) return;

    setState(() {
      _songs = files.map((f) {
        return SongModel({
          "_id": f.hashCode,
          "title": f.uri.pathSegments.last,
          "artist": "LOCAL",
          "uri": f.path,
        });
      }).toList();
      _currentIndex = 0;
    });

    await _player.setAudioSource(AudioSource.uri(Uri.file(_songs[0].uri!)));
  }

  Future<void> _saveFolderPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('music_folder', path);
  }

  Future<String?> _loadFolderPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('music_folder');
  }

  Future<void> _playPause() async {
    if (_player.playing) {
      await _player.pause();
      setState(() => _isPlaying = false);
    } else {
      await _player.play();
      setState(() => _isPlaying = true);
    }
  }

  Future<void> _next() async {
    if (_songs.isEmpty) return;
    _currentIndex = (_currentIndex + 1) % _songs.length;
    await _player.setAudioSource(AudioSource.uri(Uri.parse(_songs[_currentIndex].uri!)));
    await _player.play();
    setState(() => _isPlaying = true);
  }

  Future<void> _prev() async {
    if (_songs.isEmpty) return;
    _currentIndex = (_currentIndex - 1 + _songs.length) % _songs.length;
    await _player.setAudioSource(AudioSource.uri(Uri.parse(_songs[_currentIndex].uri!)));
    await _player.play();
    setState(() => _isPlaying = true);
  }

  @override
  Widget build(BuildContext context) {
    final song = _songs.isNotEmpty ? _songs[_currentIndex] : null;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                song?.title ?? 'NO TRACK',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                song?.artist ?? 'UNKNOWN ARTIST',
                style: const TextStyle(
                  fontSize: 26,
                  color: Colors.white70,
                ),
              ),

              const Spacer(),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: _pickFolder,
                child: const Text(
                  'WYBIERZ FOLDER',
                  style: TextStyle(
                    fontFamily: 'Digital',
                    fontSize: 22,
                    letterSpacing: 3,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 30),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _controlButton(Icons.skip_previous, _prev),
                  _controlButton(_isPlaying ? Icons.pause : Icons.play_arrow, _playPause, big: true),
                  _controlButton(Icons.skip_next, _next),
                ],
              ),

              const SizedBox(height: 30),

              // CAR HUD SPECTRUM
              CarSpectrumVisualizer(isPlaying: _isPlaying),

              const SizedBox(height: 30),

              Container(
                height: 6,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controlButton(IconData icon, VoidCallback onTap, {bool big = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: big ? 100 : 70,
        height: big ? 100 : 70,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey[900]!, Colors.black],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [
            BoxShadow(color: Colors.black54, offset: Offset(3, 3), blurRadius: 3),
            BoxShadow(color: Colors.white24, offset: Offset(-2, -2), blurRadius: 2),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: big ? 50 : 36),
      ),
    );
  }
}

/* ===========================
   CAR HUD SPECTRUM VISUALIZER
=========================== */

class CarSpectrumVisualizer extends StatefulWidget {
  final bool isPlaying;
  const CarSpectrumVisualizer({super.key, required this.isPlaying});

  @override
  State<CarSpectrumVisualizer> createState() => _CarSpectrumVisualizerState();
}

class _CarSpectrumVisualizerState extends State<CarSpectrumVisualizer> {
  static const int barCount = 28;
  final Random _random = Random();
  late Timer _timer;

  List<double> levels = List.generate(barCount, (_) => 0.1);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 90), (_) {
      setState(() {
        for (int i = 0; i < levels.length; i++) {
          if (widget.isPlaying) {
            levels[i] = 0.2 + _random.nextDouble() * 0.8;
          } else {
            levels[i] = max(0.05, levels[i] * 0.7);
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      width: double.infinity,
      child: CustomPaint(
        painter: _SpectrumPainter(levels),
      ),
    );
  }
}

class _SpectrumPainter extends CustomPainter {
  final List<double> levels;
  _SpectrumPainter(this.levels);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF00B0FF),
          Color(0xFF0077FF),
          Color(0xFF003C8F),
        ],
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final double barWidth = size.width / (levels.length * 1.5);

    for (int i = 0; i < levels.length; i++) {
      final double x = i * barWidth * 1.5;
      final double barHeight = levels[i] * size.height;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, size.height - barHeight, barWidth, barHeight),
        const Radius.circular(3),
      );

      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
