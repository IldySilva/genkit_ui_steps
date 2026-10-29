import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';

final ai = Genkit(
  plugins: [
    googleAI(
      apiKey: dotenv.env['GEMINI_API_KEY'] ??
          const String.fromEnvironment('GEMINI_API_KEY'),
    ),
  ],
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const Step2App());
}

class Step2App extends StatelessWidget {
  const Step2App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Goes AI - Step 2',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const Step2Screen(),
    );
  }
}

class Step2Screen extends StatefulWidget {
  const Step2Screen({super.key});

  @override
  State<Step2Screen> createState() => _Step2ScreenState();
}

class _Step2ScreenState extends State<Step2Screen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _answer = '';
  bool _isGenerating = false;
  late final AnimationController _cursorController;

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _cursorController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 50),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _askAiStream([String? customPrompt]) async {
    if (_isGenerating) return;

    final prompt = customPrompt ??
        (_controller.text.trim().isEmpty
            ? 'Explain why Flutter is good for building AI applications.'
            : _controller.text.trim());

    if (customPrompt != null) {
      _controller.text = customPrompt;
    }

    setState(() {
      _answer = '';
      _isGenerating = true;
    });

    try {
      final modelName = dotenv.env['GEMINI_MODEL'] ??
          const String.fromEnvironment('GEMINI_MODEL',
              defaultValue: 'gemini-2.5-flash-lite');
      final stream = ai.generateStream(
        model: googleAI.gemini(modelName),
        prompt: prompt,
      );

      await for (final chunk in stream) {
        if (!mounted) break;
        final text = chunk.text;
        if (text.isEmpty) continue;

        // Smooth visual pacing so audience sees text being written
        final segments = text.split(RegExp(r'(?<=\s|\n)'));
        for (final segment in segments) {
          if (!mounted || !_isGenerating) break;
          setState(() {
            _answer += segment;
          });
          _scrollToBottom();
          final isPunctuation = segment.contains(RegExp(r'[.,!?:;]'));
          await Future.delayed(Duration(milliseconds: isPunctuation ? 35 : 18));
        }
      }
    } catch (e) {
      setState(() {
        _answer += '\n\nError: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
        _scrollToBottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('2. Streaming')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Icon(Icons.stream, color: Colors.deepPurple),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Real-Time Streaming Generation',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Streams chunks asynchronously using ai.generateStream with a pulsing terminal cursor.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
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
                      avatar: const Icon(Icons.flutter_dash, size: 16),
                      label: const Text('Why Flutter for AI'),
                      onPressed: _isGenerating
                          ? null
                          : () => _askAiStream(
                              'Explain why Flutter is good for building AI applications.'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.speed, size: 16),
                      label: const Text('Reactive Architecture'),
                      onPressed: _isGenerating
                          ? null
                          : () => _askAiStream(
                              'How does reactive UI architecture work with streaming LLMs?'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.bolt, size: 16),
                      label: const Text('AOT Performance'),
                      onPressed: _isGenerating
                          ? null
                          : () => _askAiStream(
                              'Summarize the performance benefits of Dart Native Ahead-Of-Time compilation.'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText:
                        'e.g. Explain why Flutter is good for building AI applications.',
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
                  onSubmitted: (_) => _askAiStream(),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  onPressed: _isGenerating ? null : () => _askAiStream(),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  label: Text(_isGenerating
                      ? 'Streaming tokens...'
                      : 'Ask AI (Stream)'),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isGenerating
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                        width: _isGenerating ? 1.5 : 1,
                      ),
                    ),
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          children: [
                            TextSpan(
                              text: _answer.isEmpty
                                  ? (_isGenerating
                                      ? 'Waiting for first token...'
                                      : 'Tap a prompt above or click "Ask AI (Stream)".')
                                  : _answer,
                              style: TextStyle(
                                color: _answer.isEmpty
                                    ? Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                    : null,
                              ),
                            ),
                            if (_isGenerating)
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: FadeTransition(
                                  opacity: _cursorController,
                                  child: Container(
                                    width: 8,
                                    height: 18,
                                    margin: const EdgeInsets.only(left: 4),
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
