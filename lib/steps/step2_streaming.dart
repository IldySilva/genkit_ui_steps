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

  Future<void> _askAiStream() async {
    if (_isGenerating) return;

    final prompt = _controller.text.isEmpty
        ? 'Explain why Flutter is good for building AI applications.'
        : _controller.text;

    setState(() {
      _answer = '';
      _isGenerating = true;
    });

    try {
      final stream = ai.generateStream(
        model: googleAI.gemini('gemini-2.5-flash-lite'),
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
        _answer += '\n\n❌ Error: $e';
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText:
                    'Explain why Flutter is good for building AI applications.',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _askAiStream(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isGenerating ? null : _askAiStream,
              child: const Text('Ask AI (Stream)'),
            ),
            const SizedBox(height: 32),
            if (_answer.isNotEmpty || _isGenerating) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'AI Response:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        children: [
                          TextSpan(text: _answer),
                          if (_isGenerating)
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: FadeTransition(
                                opacity: _cursorController,
                                child: Container(
                                  width: 8,
                                  height: 18,
                                  margin: const EdgeInsets.only(left: 4),
                                  color: Theme.of(context).colorScheme.primary,
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
          ],
        ),
      ),
    );
  }
}
