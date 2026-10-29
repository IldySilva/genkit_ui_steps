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
      title: 'Flutter Goes AI - Step 11 (A2UI Generative UI)',
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
      model: googleAI.gemini('gemini-2.5-flash-lite'),
    );

    // 2. Initialize GenUI SurfaceController with basic catalog matching plugin ID
    final catalog = BasicCatalogItems.asCatalog().copyWith(
      catalogId: basicCatalogId,
    );
    _surfaceController = SurfaceController(catalogs: [catalog]);

    // 3. Listen to surface updates emitted by the AI stream
    _surfaceController.surfaceUpdates.listen((update) {
      if (update is SurfaceAdded) {
        setState(() {
          if (!_surfaceIds.contains(update.surfaceId)) {
            _surfaceIds.add(update.surfaceId);
            _activityLogs.add('✨ [A2UI] Rendered surface: ${update.surfaceId}');
          }
        });
      }
    });
  }

  Future<void> _generateUi() async {
    final prompt = _controller.text.trim().isEmpty
        ? 'Show me an interactive weather card for Tokyo with temperature, humidity, and a refresh button.'
        : _controller.text.trim();

    setState(() {
      _isLoading = true;
      _proseOutput = '';
      _surfaceIds.clear();
      _activityLogs.clear();
      _activityLogs.add('🤔 Prompting model with A2UI Generative UI middleware...');
    });

    try {
      final stream = ai.generateStream(
        prompt: prompt,
        use: [
          a2ui(),
        ],
      );

      await for (final chunk in stream) {
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

      setState(() {
        _activityLogs.add('✓ Generative UI streaming complete.');
      });
    } catch (e) {
      setState(() {
        _activityLogs.add('❌ Error: $e');
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
      appBar: AppBar(title: const Text('11. Generative UI (A2UI + genui)')),
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
                      hintText: 'e.g. "Create a product card for running shoes with size selector"',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _isLoading ? null : _generateUi(),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _generateUi,
                    child: const Text('Stream Generative UI Surface'),
                  ),
                  const SizedBox(height: 16),
                  if (_proseOutput.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Text(
                        _proseOutput,
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ),
                  const Divider(),
                  const Text(
                    'Rendered GenUI Surface:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _surfaceIds.isEmpty
                        ? Center(
                            child: Text(
                              _isLoading
                                  ? 'Generating UI surface in real-time...'
                                  : 'Click above to let the AI stream dynamic Flutter widgets.',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _surfaceIds.length,
                            itemBuilder: (context, index) {
                              final id = _surfaceIds[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                elevation: 3,
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Surface(
                                    surfaceContext: _surfaceController.contextFor(id),
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
                    'A2UI PROTOCOL ACTIVITY',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isLoading)
                    const LinearProgressIndicator(color: Colors.greenAccent),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _activityLogs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
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
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
