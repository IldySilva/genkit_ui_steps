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
      debugShowCheckedModeBanner: false,
      title: 'Flutter Goes AI - Step 6 (Embeddings)',
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
      description:
          'Futuristic high-tech aesthetic with neon violet, electric pink and dark alleys.',
      color: const Color(0xFFE040FB),
    ),
    ThemeItem(
      title: 'Ocean Deep Dive',
      description:
          'Calm marine depths, deep turquoise blue waters and oceanic tranquility.',
      color: const Color(0xFF00B0FF),
    ),
    ThemeItem(
      title: 'Autumn Forest & Rain',
      description:
          'Cozy autumn atmosphere, warm falling leaves, amber wood and rainy evening warmth.',
      color: const Color(0xFFFF6D00),
    ),
    ThemeItem(
      title: 'Minimalist Charcoal',
      description:
          'Strict monochrome dark charcoal, clean minimalist productivity and shadows.',
      color: const Color(0xFF37474F),
    ),
    ThemeItem(
      title: 'Emerald Zen Garden',
      description:
          'Relaxing herbal green moss, Japanese garden stone paths and peaceful bamboo.',
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
        embedder: googleAI.textEmbedding('gemini-embedding-001'),
      );

      for (var i = 0; i < _catalog.length; i++) {
        _catalog[i].embedding = embeddings[i].embedding;
      }

      if (mounted) {
        setState(() {
          _statusMessage = 'Catalog indexed (${_catalog.length} vectors ready).';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Error indexing catalog: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
  Future<void> _searchTheme([String? customQuery]) async {
    final query = customQuery ?? _controller.text.trim();
    if (query.isEmpty) return;

    if (customQuery != null) {
      _controller.text = customQuery;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Embedding query: "$query"...';
      _similarityResults = [];
    });

    try {
      final queryEmbeddingResult = await ai.embed(
        documents: [
          DocumentData(content: [TextPart(text: query)])
        ],
        embedder: googleAI.textEmbedding('gemini-embedding-001'),
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

      if (mounted) {
        setState(() {
          _similarityResults = scores;
          _statusMessage =
              'Matched "${topMatch.title}" ($matchPercentage% similarity)';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Search failed: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildSimilarityPanel({bool isDarkBackground = true}) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDarkBackground
            ? Colors.black87
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'VECTOR SIMILARITY RANKING',
                style: TextStyle(
                  color: isDarkBackground
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  fontSize: 13,
                ),
              ),
              if (_similarityResults.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Cosine Sim',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    color: Colors.greenAccent,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
          if (_similarityResults.isEmpty && !_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Text(
                'Run a semantic query or tap a quick prompt to rank catalog themes by vector distance.',
                style: TextStyle(
                  color: isDarkBackground
                      ? Colors.white60
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ),
          ..._similarityResults.map((result) {
            final item = result['item'] as ThemeItem;
            final similarity = result['similarity'] as double;
            final percentage = (similarity * 100).toStringAsFixed(1);
            final isTop = _similarityResults.first == result;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: item.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item.title,
                            style: TextStyle(
                              color: isDarkBackground
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.onSurface,
                              fontWeight:
                                  isTop ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '$percentage%',
                        style: TextStyle(
                          color: isTop
                              ? Colors.greenAccent
                              : (isDarkBackground
                                  ? Colors.white70
                                  : Colors.black87),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: similarity.clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor:
                          isDarkBackground ? Colors.white12 : Colors.black12,
                      valueColor: AlwaysStoppedAnimation(
                        isTop ? Colors.greenAccent : Colors.tealAccent,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    final isError = _statusMessage.toLowerCase().contains('error') ||
        _statusMessage.toLowerCase().contains('fail');
    final isSuccess = _similarityResults.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isError
            ? Colors.red.withValues(alpha: 0.12)
            : (isSuccess
                ? Colors.green.withValues(alpha: 0.12)
                : Theme.of(context).colorScheme.surfaceContainerHighest),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isError
              ? Colors.red.shade300
              : (isSuccess ? Colors.green.shade400 : Colors.transparent),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline
                : (isSuccess ? Icons.check_circle_outline : Icons.info_outline),
            size: 20,
            color: isError
                ? Colors.red
                : (isSuccess
                    ? Colors.green
                    : Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _statusMessage,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSuccess ? FontWeight.bold : FontWeight.w500,
                color: isError ? Colors.red.shade700 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Pre-indexed Theme Catalog',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            Text(
              '${_catalog.where((c) => c.embedding != null).length}/${_catalog.length} vectors ready',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _catalog.length,
          itemBuilder: (context, index) {
            final item = _catalog[index];
            final isCurrent = widget.currentColor == item.color;

            return Card(
              elevation: isCurrent ? 3 : 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: isCurrent
                    ? BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      )
                    : BorderSide.none,
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: item.color,
                  child: isCurrent
                      ? const Icon(Icons.palette, color: Colors.white, size: 18)
                      : null,
                ),
                title: Text(
                  item.title,
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  item.description,
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: item.embedding != null
                    ? const Icon(Icons.check_circle,
                        color: Colors.green, size: 20)
                    : const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                onTap: () {
                  widget.onColorSelected(item.color);
                  _controller.text = item.description;
                  setState(() {});
                },
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('6. Embeddings'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 650;

          final infoCard = Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Icon(Icons.hub, color: Colors.deepPurple),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Semantic Search & Vector Embeddings',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Uses gemini-embedding-001 to convert themes to vectors. Calculates cosine similarity with 0 hallucinations.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );

          final quickPrompts = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quick Prompts:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.cloudy_snowing, size: 16),
                    label: const Text('Rainy & Cozy'),
                    onPressed: _isLoading
                        ? null
                        : () => _searchTheme(
                            'Cozy rainy afternoon with warm tea'),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.nightlife, size: 16),
                    label: const Text('Cyberpunk Party'),
                    onPressed: _isLoading
                        ? null
                        : () => _searchTheme(
                            'Futuristic electronic cyberpunk neon vibes'),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.water_drop, size: 16),
                    label: const Text('Ocean Depths'),
                    onPressed: _isLoading
                        ? null
                        : () => _searchTheme(
                            'Deep sea marine exploration and blue waves'),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.park, size: 16),
                    label: const Text('Zen Garden'),
                    onPressed: _isLoading
                        ? null
                        : () => _searchTheme(
                            'Peaceful bamboo garden with green moss and stone'),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.dark_mode, size: 16),
                    label: const Text('Minimal Charcoal'),
                    onPressed: _isLoading
                        ? null
                        : () => _searchTheme(
                            'Clean dark monochrome workspace for maximum focus'),
                  ),
                ],
              ),
            ],
          );

          final searchInput = TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'e.g. "I want something rainy and cozy"',
              border: const OutlineInputBorder(),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _controller.clear();
                        setState(() {});
                      },
                    )
                  : null,
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _searchTheme(),
          );

          final searchButton = ElevatedButton.icon(
            icon: const Icon(Icons.search),
            onPressed: _isLoading ? null : () => _searchTheme(),
            label: Text(_isLoading
                ? 'Searching vector space...'
                : 'Find Theme with Semantic Embedding'),
          );

          if (isMobile) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  infoCard,
                  const SizedBox(height: 12),
                  quickPrompts,
                  const SizedBox(height: 16),
                  searchInput,
                  const SizedBox(height: 12),
                  searchButton,
                  const SizedBox(height: 16),
                  _buildStatusBanner(),
                  const SizedBox(height: 16),
                  _buildSimilarityPanel(isDarkBackground: true),
                  const SizedBox(height: 20),
                  _buildCatalogSection(),
                ],
              ),
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      infoCard,
                      const SizedBox(height: 12),
                      quickPrompts,
                      const SizedBox(height: 16),
                      searchInput,
                      const SizedBox(height: 12),
                      searchButton,
                      const SizedBox(height: 16),
                      _buildStatusBanner(),
                      const SizedBox(height: 20),
                      _buildCatalogSection(),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Container(
                  color: Colors.black87,
                  padding: const EdgeInsets.all(16.0),
                  child: _buildSimilarityPanel(isDarkBackground: true),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
