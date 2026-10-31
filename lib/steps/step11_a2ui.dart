import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_a2ui/a2ui.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:genui/genui.dart' hide basicCatalogId, DataPart;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const Step11App());
}

class Step11App extends StatelessWidget {
  const Step11App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Goes AI - Step 10 (A2UI Generative UI)',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const Step11Screen(),
    );
  }
}

class Step11Screen extends StatefulWidget {
  const Step11Screen({super.key});

  @override
  State<Step11Screen> createState() => _Step11ScreenState();
}

class _Step11ScreenState extends State<Step11Screen> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  final List<String> _surfaceIds = [];
  String _proseOutput = '';
  final List<String> _activityLogs = [];

  late final Genkit ai;
  late final SurfaceController _surfaceController;

  @override
  void initState() {
    super.initState();

    // 1. Initialize Genkit with Google GenAI and A2uiPlugin
    ai = Genkit(
      plugins: [
        googleAI(
          apiKey: dotenv.env['GEMINI_API_KEY'] ??
              const String.fromEnvironment('GEMINI_API_KEY'),
        ),
        A2uiPlugin(),
      ],
      model: googleAI.gemini(dotenv.env['GEMINI_MODEL'] ??
          const String.fromEnvironment('GEMINI_MODEL',
              defaultValue: 'gemini-2.5-flash-lite')),
    );

    // 2. Initialize GenUI SurfaceController with basic catalog matching plugin ID
    final catalog = BasicCatalogItems.asCatalog().copyWith(
      catalogId: basicCatalogId,
    );
    _surfaceController = SurfaceController(catalogs: [catalog]);

    // 3. Listen to surface updates emitted by the AI stream
    _surfaceController.surfaceUpdates.listen((update) {
      if (update is SurfaceAdded) {
        if (mounted) {
          setState(() {
            if (!_surfaceIds.contains(update.surfaceId)) {
              _surfaceIds.add(update.surfaceId);
              _activityLogs.add('[A2UI] Rendered surface: ${update.surfaceId}');
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _generateUi([String? customPrompt]) async {
    final prompt = customPrompt ??
        (_controller.text.trim().isEmpty
            ? 'Show me an interactive weather card for Tokyo with temperature, humidity, and a refresh button.'
            : _controller.text.trim());

    if (customPrompt != null) {
      _controller.text = customPrompt;
    }

    setState(() {
      _isLoading = true;
      _proseOutput = '';
      _surfaceIds.clear();
      _activityLogs.clear();
      _activityLogs
          .add('[A2UI] Prompting model with A2UI Generative UI middleware...');
    });

    try {
      final stream = ai.generateStream(
        prompt: prompt,
        use: [
          a2ui(),
        ],
      );

      await for (final chunk in stream) {
        if (!mounted) break;
        if (chunk.text.isNotEmpty) {
          setState(() {
            _proseOutput += chunk.text;
          });
        }

        // Extract A2UI JSON envelopes from chunk content
        final envelopes = a2uiEnvelopesFromParts(chunk.content);
        for (final envelope in envelopes) {
          _surfaceController.handleMessage(core.A2uiMessage.fromJson(envelope));
        }
      }

      if (mounted) {
        setState(() {
          _activityLogs.add('[Done] Generative UI streaming complete.');
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _activityLogs.add('[Error] $e');
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

  Widget _buildActivityPanel({bool isExpanded = false}) {
    final content = Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'A2UI PROTOCOL ACTIVITY',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  fontSize: 12,
                ),
              ),
              if (_activityLogs.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep,
                      color: Colors.white70, size: 18),
                  tooltip: 'Clear activity log',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(() => _activityLogs.clear()),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_isLoading) ...[
            const ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(2)),
              child: LinearProgressIndicator(
                color: Colors.greenAccent,
                backgroundColor: Colors.white12,
                minHeight: 3,
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (isExpanded)
            Expanded(
              child: ListView.builder(
                itemCount: _activityLogs.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Text(
                      _activityLogs[index],
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _activityLogs.isEmpty
                  ? [
                      const Text(
                        'No protocol events yet. Tap a quick prompt to generate dynamic surfaces.',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ]
                  : _activityLogs.map((log) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Text(
                          log,
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      );
                    }).toList(),
            ),
        ],
      ),
    );

    return isExpanded ? Expanded(child: content) : content;
  }

  Widget _buildRenderedSurfaces() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Rendered GenUI Surfaces:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            if (_surfaceIds.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_surfaceIds.length} active surface(s)',
                  style: const TextStyle(
                      color: Colors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_surfaceIds.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Center(
              child: Text(
                _isLoading
                    ? 'Generating UI surface in real-time...'
                    : 'Tap a prompt above to stream declarative Flutter widgets.',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          )
        else
          Column(
            children: _surfaceIds.map((id) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Surface(
                    surfaceContext: _surfaceController.contextFor(id),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('10. Generative UI'),
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
                  Icon(Icons.dashboard_customize_outlined,
                      color: Colors.deepPurple),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'A2UI Generative UI (Dynamic Surfaces)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Streams declarative JSON envelopes via A2UI middleware, rendered live into native Flutter widgets by the GenUI SurfaceController.',
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
                    avatar: const Icon(Icons.wb_sunny_outlined, size: 16),
                    label: const Text('Tokyo Weather'),
                    onPressed: _isLoading
                        ? null
                        : () => _generateUi(
                            'Show me an interactive weather card for Tokyo with temperature, humidity, and a refresh button.'),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.shopping_bag_outlined, size: 16),
                    label: const Text('Running Shoe'),
                    onPressed: _isLoading
                        ? null
                        : () => _generateUi(
                            'Create a product card for running shoes with size selector and Buy button.'),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.flight_takeoff, size: 16),
                    label: const Text('Boarding Pass'),
                    onPressed: _isLoading
                        ? null
                        : () => _generateUi(
                            'Display a flight boarding pass for flight JL006 from Tokyo to New York.'),
                  ),
                ],
              ),
            ],
          );

          final promptInput = TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'e.g. "Create a product card for running shoes..."',
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
            onSubmitted: (_) => _isLoading ? null : _generateUi(),
          );

          final generateButton = ElevatedButton.icon(
            icon: const Icon(Icons.auto_awesome),
            onPressed: _isLoading ? null : () => _generateUi(),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            label: Text(
                _isLoading ? 'Streaming widgets...' : 'Stream Generative UI'),
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
                  promptInput,
                  const SizedBox(height: 12),
                  generateButton,
                  if (_proseOutput.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      _proseOutput,
                      style: const TextStyle(
                          fontStyle: FontStyle.italic, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildRenderedSurfaces(),
                  const SizedBox(height: 16),
                  _buildActivityPanel(isExpanded: false),
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
                      promptInput,
                      const SizedBox(height: 12),
                      generateButton,
                      if (_proseOutput.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          _proseOutput,
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _buildRenderedSurfaces(),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Container(
                  color: Colors.black87,
                  padding: const EdgeInsets.all(16.0),
                  child: _buildActivityPanel(isExpanded: true),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
