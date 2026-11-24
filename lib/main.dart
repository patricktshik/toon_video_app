import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

// Remplace par l'adresse de TON serveur (voir Étape 3).
const String kBackendUrl = 'https://ton-serveur.example.com';

void main() => runApp(const ToonApp());

class ToonApp extends StatelessWidget {
  const ToonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Toon Video',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
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
      // 1. Lancer la génération
      final start = await http.post(
        Uri.parse('$kBackendUrl/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idea': idea}),
      );
      if (start.statusCode != 200) {
        throw Exception('Erreur serveur (${start.statusCode})');
      }
      final jobId = jsonDecode(start.body)['jobId'] as String;

      // 2. Attendre le résultat (toutes les 4 secondes)
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
          throw Exception('La génération a échoué.');
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
      appBar: AppBar(title: const Text('Toon Video')),
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
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
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
              label: Text(_loading ? 'Génération en cours...' : 'Générer la vidéo'),
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
      appBar: AppBar(title: const Text('Ta vidéo')),
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
