import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const Step7App());
}

// 1. Custom Generate Middleware that tracks model latency
class LatencyLoggingMiddleware extends GenerateMiddleware {
  final Function(String) onLog;

  LatencyLoggingMiddleware({required this.onLog});

  @override
  Future<ModelResponse> model(
    ModelRequest request,
    ActionFnArg<ModelResponseChunk, ModelRequest, void> ctx,
    Future<ModelResponse> Function(
      ModelRequest request,
      ActionFnArg<ModelResponseChunk, ModelRequest, void> ctx,
    ) next,
  ) async {
    final stopwatch = Stopwatch()..start();
    onLog(
        '[Middleware] Calling model with ${request.messages.length} message(s)...');

    final response = await next(request, ctx);
    stopwatch.stop();

    onLog('[Middleware] Model responded in ${stopwatch.elapsedMilliseconds}ms');
    return response;
  }
}

class Step7App extends StatelessWidget {
  const Step7App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Goes AI - Step 7 (Middlewares & Cancellation)',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const Step7Screen(),
    );
  }
}

class Step7Screen extends StatefulWidget {
  const Step7Screen({super.key});

  @override
  State<Step7Screen> createState() => _Step7ScreenState();
}

class _Step7ScreenState extends State<Step7Screen> {
  final TextEditingController _controller = TextEditingController();
  String _generatedText = '';
  bool _isStreaming = false;
  final List<String> _logs = [];

  StreamSubscription<GenerateResponseChunk>? _subscription;
  late final Genkit ai;
  late final dynamic latencyMiddleware;

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
      model: googleAI.gemini(dotenv.env['GEMINI_MODEL'] ??
          const String.fromEnvironment('GEMINI_MODEL',
              defaultValue: 'gemini-2.5-flash-lite')),
    );

    // Register custom middleware definition
    latencyMiddleware = ai.defineGenerateMiddleware<void>(
      name: 'latencyLogger',
      create: (config, ctx) => LatencyLoggingMiddleware(
        onLog: (msg) {
          if (mounted) {
            setState(() {
              _logs.add(msg);
            });
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startStream([String? customPrompt]) async {
    final prompt = customPrompt ??
        (_controller.text.trim().isEmpty
            ? 'Write a detailed 5-paragraph essay on the history of Flutter and cross-platform UI.'
            : _controller.text.trim());

    if (customPrompt != null) {
      _controller.text = customPrompt;
    }

    setState(() {
      _generatedText = '';
      _isStreaming = true;
      _logs.clear();
      _logs.add(
          '[Stream] Starting stream generation with custom middleware & retry...');
    });

    try {
      final stream = ai.generateStream(
        prompt: prompt,
        use: [
          latencyMiddleware(),
          retry(maxRetries: 2),
        ],
      );

      _subscription = stream.listen(
        (chunk) {
          if (mounted) {
            setState(() {
              _generatedText += chunk.text;
            });
          }
        },
        onDone: () {
          if (mounted) {
            setState(() {
              _isStreaming = false;
              _logs.add('[Done] Stream completed successfully.');
            });
          }
        },
        onError: (err) {
          if (mounted) {
            setState(() {
              _isStreaming = false;
              _logs.add('[Error] Stream error: $err');
            });
          }
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isStreaming = false;
          _logs.add('[Error] Exception: $e');
        });
      }
    }
  }

  // Real-time cancellation by cancelling the stream subscription
  Future<void> _cancelStream() async {
    if (_subscription != null) {
      await _subscription!.cancel();
      _subscription = null;
      if (mounted) {
        setState(() {
          _isStreaming = false;
          _logs.add('[Cancelled] User canceled stream generation mid-way.');
        });
      }
    }
  }

  Color _getLogColor(String log) {
    if (log.contains('[Error]')) return Colors.redAccent;
    if (log.contains('[Cancelled]')) return Colors.amberAccent;
    if (log.contains('[Done]')) return Colors.greenAccent;
    if (log.contains('[Middleware]')) return Colors.cyanAccent;
    return Colors.white70;
  }

  Widget _buildStreamingOutput({bool isExpanded = false}) {
    final content = Container(
      padding: const EdgeInsets.all(14),
      constraints: isExpanded
          ? const BoxConstraints()
          : const BoxConstraints(minHeight: 140, maxHeight: 260),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: _isStreaming
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
          width: _isStreaming ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: SingleChildScrollView(
        child: Text(
          _generatedText.isEmpty
              ? (_isStreaming
                  ? 'Waiting for first token...'
                  : 'Click "Start Stream" or choose a quick prompt.')
              : _generatedText,
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: _generatedText.isEmpty
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  'Streaming Output',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                if (_isStreaming) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    height: 12,
                    width: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
            if (_generatedText.isNotEmpty)
              Text(
                '${_generatedText.split(' ').where((w) => w.isNotEmpty).length} words',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (isExpanded) Expanded(child: content) else content,
      ],
    );
  }

  Widget _buildLogPanel({bool isExpanded = false}) {
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
                'MIDDLEWARE & EVENT LOGS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  fontSize: 12,
                ),
              ),
              if (_logs.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep,
                      color: Colors.white70, size: 18),
                  tooltip: 'Clear logs',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(() => _logs.clear()),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_isStreaming) ...[
            const ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(2)),
              child: LinearProgressIndicator(
                color: Colors.cyanAccent,
                backgroundColor: Colors.white12,
                minHeight: 3,
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (isExpanded)
            Expanded(
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Text(
                      _logs[index],
                      style: TextStyle(
                        color: _getLogColor(_logs[index]),
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
              children: _logs.isEmpty
                  ? [
                      const Text(
                        'No events recorded yet. Start a stream to observe latency and retry middlewares.',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ]
                  : _logs.map((log) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Text(
                          log,
                          style: TextStyle(
                            color: _getLogColor(log),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('6. Middlewares'),
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
                  Icon(Icons.tune, color: Colors.deepPurple),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Middlewares & Stream Cancellation',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Intercepts requests to measure latency (Stopwatch), auto-retry failures (retry(2)), and cancel streaming mid-flight.',
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
                    avatar: const Icon(Icons.history_edu, size: 16),
                    label: const Text('Flutter History'),
                    onPressed: _isStreaming
                        ? null
                        : () => _startStream(
                            'Write a detailed 5-paragraph essay on the history of Flutter and cross-platform UI.'),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.psychology, size: 16),
                    label: const Text('AI Agents Future'),
                    onPressed: _isStreaming
                        ? null
                        : () => _startStream(
                            'Explain how autonomous AI agents will transform mobile application architecture.'),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.auto_stories, size: 16),
                    label: const Text('Developer Story'),
                    onPressed: _isStreaming
                        ? null
                        : () => _startStream(
                            'Tell an engaging story about an engineer building an intelligent remote-controlled Flutter app.'),
                  ),
                ],
              ),
            ],
          );

          final promptInput = TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'e.g. Write a long essay on cross-platform frameworks...',
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
            onSubmitted: (_) => _isStreaming ? null : _startStream(),
          );

          final actionButtons = Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  onPressed: _isStreaming ? null : () => _startStream(),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  label: Text(_isStreaming ? 'Streaming...' : 'Start Stream'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.stop_circle_outlined),
                  onPressed: _isStreaming ? _cancelStream : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: BorderSide(
                      color: _isStreaming ? Colors.red : Colors.grey.shade300,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  label: const Text('Cancel'),
                ),
              ),
            ],
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
                  actionButtons,
                  const SizedBox(height: 16),
                  _buildStreamingOutput(isExpanded: false),
                  const SizedBox(height: 16),
                  _buildLogPanel(isExpanded: false),
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
                      actionButtons,
                      const SizedBox(height: 16),
                      _buildStreamingOutput(isExpanded: false),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Container(
                  color: Colors.black87,
                  padding: const EdgeInsets.all(16.0),
                  child: _buildLogPanel(isExpanded: true),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
