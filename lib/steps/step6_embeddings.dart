import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const Step6App());
}

class ThemeItem {
  final String title;
  final String description;
  final Color color;
  List<double>? embedding;

  ThemeItem({
    required this.title,
    required this.description,
    required this.color,
  });
}

class Step6App extends StatefulWidget {
  const Step6App({super.key});

  @override
  State<Step6App> createState() => _Step6AppState();
}

class _Step6AppState extends State<Step6App> {
  Color _themeColor = Colors.deepPurple;

  void setTheme(Color color) {
    setState(() {
      _themeColor = color;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Goes AI - Step 6 (Embeddings & Semantic Search)',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _themeColor,
          brightness: _themeColor.computeLuminance() > 0.5
              ? Brightness.light
              : Brightness.dark,
        ),
      ),
      home: Step6Screen(
        currentColor: _themeColor,
        onColorSelected: setTheme,
      ),
    );
  }
}

class Step6Screen extends StatefulWidget {
  final Color currentColor;
  final Function(Color) onColorSelected;

  const Step6Screen({
    super.key,
    required this.currentColor,
    required this.onColorSelected,
  });

  @override
  State<Step6Screen> createState() => _Step6ScreenState();
}

class _Step6ScreenState extends State<Step6Screen> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  String _statusMessage = 'Catalog not indexed yet.';
  List<Map<String, dynamic>> _similarityResults = [];

  final List<ThemeItem> _catalog = [
    ThemeItem(
      title: 'Cyberpunk Neon',
      description: 'Futuristic high-tech aesthetic with neon violet, electric pink and dark alleys.',
      color: const Color(0xFFE040FB),
    ),
    ThemeItem(
      title: 'Ocean Deep Dive',
      description: 'Calm marine depths, deep turquoise blue waters and oceanic tranquility.',
      color: const Color(0xFF00B0FF),
    ),
    ThemeItem(
      title: 'Autumn Forest & Rain',
      description: 'Cozy autumn atmosphere, warm falling leaves, amber wood and rainy evening warmth.',
      color: const Color(0xFFFF6D00),
    ),
    ThemeItem(
      title: 'Minimalist Charcoal',
      description: 'Strict monochrome dark charcoal, clean minimalist productivity and shadows.',
      color: const Color(0xFF37474F),
    ),
    ThemeItem(
      title: 'Emerald Zen Garden',
      description: 'Relaxing herbal green moss, Japanese garden stone paths and peaceful bamboo.',
      color: const Color(0xFF00C853),
    ),
  ];

  late final Genkit ai;

  @override
  void initState() {
    super.initState();
    ai = Genkit(
      plugins: [
        googleAI(
          apiKey: dotenv.env['GEMINI_API_KEY'] ??
              const String.fromEnvironment('GEMINI_API_KEY'),
        ),
      ],
    );
    _indexCatalog();
  }

  // Pre-compute embeddings for the catalog using ai.embed
  Future<void> _indexCatalog() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Generating vector embeddings for catalog...';
    });

    try {
      final documents = _catalog
          .map((item) => DocumentData(
                content: [TextPart(text: '${item.title}: ${item.description}')],
              ))
          .toList();

      final embeddings = await ai.embed(
        documents: documents,
        embedder: googleAI.textEmbedding('text-embedding-004'),
      );

      for (var i = 0; i < _catalog.length; i++) {
        _catalog[i].embedding = embeddings[i].embedding;
      }

      setState(() {
        _statusMessage = 'Catalog indexed (${_catalog.length} vectors ready).';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error indexing catalog: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Cosine similarity between two vector embeddings
  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    for (var i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0.0 || normB == 0.0) return 0.0;
    return dotProduct / (math.sqrt(normA) * math.sqrt(normB));
  }

  // Find nearest theme using vector embedding search
  Future<void> _searchTheme() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Embedding search query: "$query"...';
      _similarityResults = [];
    });

    try {
      final queryEmbeddingResult = await ai.embed(
        documents: [
          DocumentData(content: [TextPart(text: query)])
        ],
        embedder: googleAI.textEmbedding('text-embedding-004'),
      );

      final queryVector = queryEmbeddingResult.first.embedding;

      final scores = <Map<String, dynamic>>[];
      for (final item in _catalog) {
        if (item.embedding != null) {
          final similarity = _cosineSimilarity(queryVector, item.embedding!);
          scores.add({
            'item': item,
            'similarity': similarity,
          });
        }
      }

      scores.sort((a, b) =>
          (b['similarity'] as double).compareTo(a['similarity'] as double));

      final topMatch = scores.first['item'] as ThemeItem;
      widget.onColorSelected(topMatch.color);
      final matchPercentage =
          ((scores.first['similarity'] as double) * 100).toStringAsFixed(1);

      setState(() {
        _similarityResults = scores;
        _statusMessage = 'Matched "${topMatch.title}" ($matchPercentage% match)';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Search failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('8. Embeddings & Semantic Search')),
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'e.g. "I want something rainy and cozy" or "techno club neon vibes"',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _searchTheme(),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _searchTheme,
                    child: const Text('Find Theme with Semantic Embedding'),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _statusMessage,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Pre-indexed Theme Catalog:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _catalog.length,
                      itemBuilder: (context, index) {
                        final item = _catalog[index];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(backgroundColor: item.color),
                            title: Text(item.title),
                            subtitle: Text(item.description),
                            trailing: item.embedding != null
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.black87,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'VECTOR SIMILARITY SCORES',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isLoading)
                    const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  ..._similarityResults.map((result) {
                    final item = result['item'] as ThemeItem;
                    final similarity = result['similarity'] as double;
                    final percentage = (similarity * 100).toStringAsFixed(1);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.title}: $percentage%',
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: similarity.clamp(0.0, 1.0),
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation(Colors.greenAccent),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
