import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

const String kBackendUrl = 'https://toon-server.onrender.com';

void main() => runApp(const ToonApp());

class ToonApp extends StatelessWidget {
  const ToonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Toon Video',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFF0E0E12),
        useMaterial3: true,
      ),
      home: const IdeaScreen(),
    );
  }
}

class IdeaScreen extends StatefulWidget {
  const IdeaScreen({super.key});

  @override
  State<IdeaScreen> createState() => _IdeaScreenState();
}

class _IdeaScreenState extends State<IdeaScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _generate() async {
    final idea = _controller.text.trim();
    if (idea.isEmpty) {
      setState(() => _error = 'Écris ton idée d\'abord.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final start = await http.post(
        Uri.parse('$kBackendUrl/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idea': idea}),
      );
      if (start.statusCode != 200) {
        throw Exception('Erreur serveur (${start.statusCode})');
      }
      final jobId = jsonDecode(start.body)['jobId'] as String;

      String? videoUrl;
      for (int i = 0; i < 60; i++) {
        await Future.delayed(const Duration(seconds: 4));
        final res = await http.get(Uri.parse('$kBackendUrl/status/$jobId'));
        final data = jsonDecode(res.body);
        if (data['status'] == 'done') {
          videoUrl = data['videoUrl'] as String;
          break;
        }
        if (data['status'] == 'failed') {
          throw Exception(data['error'] ?? 'La génération a échoué.');
        }
      }
      if (videoUrl == null) throw Exception('Trop long, réessaie.');

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PlayerScreen(url: videoUrl!)),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Toon Video'),
        backgroundColor: const Color(0xFF0E0E12),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Raconte ton idée, je la transforme en dessin animé.',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              maxLines: 5,
              maxLength: 300,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Ex : un chat astronaute qui danse sur la lune',
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            FilledButton.icon(
              onPressed: _loading ? null : _generate,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.movie_creation),
              label: Text(
                _loading ? 'Génération en cours...' : 'Générer la vidéo',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlayerScreen extends StatefulWidget {
  final String url;
  const PlayerScreen({super.key, required this.url});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final VideoPlayerController _vc;

  @override
  void initState() {
    super.initState();
    _vc = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        setState(() {});
        _vc.setLooping(true);
        _vc.play();
      });
  }

  @override
  void dispose() {
    _vc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ta vidéo'),
        backgroundColor: const Color(0xFF0E0E12),
      ),
      body: Center(
        child: _vc.value.isInitialized
            ? AspectRatio(
                aspectRatio: _vc.value.aspectRatio,
                child: VideoPlayer(_vc),
              )
            : const CircularProgressIndicator(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() {
          _vc.value.isPlaying ? _vc.pause() : _vc.play();
        }),
        child: Icon(_vc.value.isPlaying ? Icons.pause : Icons.play_arrow),
      ),
    );
  }
}
