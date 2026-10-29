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
    onLog('[Middleware] Calling model with ${request.messages.length} message(s)...');
    
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
      model: googleAI.gemini('gemini-2.5-flash-lite'),
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
    super.dispose();
  }

  Future<void> _startStream() async {
    final prompt = _controller.text.trim().isEmpty
        ? 'Write a detailed 5-paragraph essay on the history of Flutter and cross-platform UI.'
        : _controller.text.trim();

    setState(() {
      _generatedText = '';
      _isStreaming = true;
      _logs.clear();
      _logs.add('[Stream] Starting stream generation with custom middleware & retry...');
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
          setState(() {
            _generatedText += chunk.text;
          });
        },
        onDone: () {
          setState(() {
            _isStreaming = false;
            _logs.add('[Done] Stream completed successfully.');
          });
        },
        onError: (err) {
          setState(() {
            _isStreaming = false;
            _logs.add('[Error] Stream error: $err');
          });
        },
        cancelOnError: true,
      );
    } catch (e) {
      setState(() {
        _isStreaming = false;
        _logs.add('[Error] Exception: $e');
      });
    }
  }

  // Real-time cancellation by cancelling the stream subscription
  Future<void> _cancelStream() async {
    if (_subscription != null) {
      await _subscription!.cancel();
      _subscription = null;
      setState(() {
        _isStreaming = false;
        _logs.add('[Cancelled] User canceled stream generation mid-way.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('9. Middlewares & Cancellation')),
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
                      hintText: 'Write a long essay on cross-platform frameworks...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _isStreaming ? null : _startStream(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isStreaming ? null : _startStream,
                          child: const Text('Start Streaming'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isStreaming ? _cancelStream : null,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('Cancel Stream'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Streaming Output:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          _generatedText.isEmpty
                              ? (_isStreaming ? 'Waiting for first token...' : 'Click "Start Streaming" above.')
                              : _generatedText,
                        ),
                      ),
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
                    'MIDDLEWARE & EVENT LOGS',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isStreaming)
                    const LinearProgressIndicator(color: Colors.cyanAccent),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            _logs[index],
                            style: const TextStyle(
                              color: Colors.cyanAccent,
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
