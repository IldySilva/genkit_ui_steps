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
      title: 'Flutter Goes AI - Step 2 (Streaming)',
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
  int _chunkCount = 0;
  int _tokenCount = 0;
  double _elapsedSeconds = 0.0;
  Timer? _timer;
  Stopwatch? _stopwatch;

  // Presentation Pacing Settings
  bool _presentationPacing = true;
  final double _typingSpeedMs = 18.0; // milliseconds per token/character

  // Blinking cursor controller
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
    _timer?.cancel();
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

    final promptText = customPrompt ??
        (_controller.text.isEmpty
            ? 'Explain why token streaming provides a better user experience in Flutter.'
            : _controller.text);

    if (customPrompt != null) {
      _controller.text = customPrompt;
    }

    setState(() {
      _answer = '';
      _isGenerating = true;
      _chunkCount = 0;
      _tokenCount = 0;
      _elapsedSeconds = 0.0;
    });

    _stopwatch = Stopwatch()..start();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_stopwatch != null) {
        setState(() {
          _elapsedSeconds = _stopwatch!.elapsedMilliseconds / 1000.0;
        });
      }
    });

    try {
      final stream = ai.generateStream(
        model: googleAI.gemini('gemini-3.1-flash-lite'),
        prompt: promptText,
      );

      await for (final chunk in stream) {
        if (!mounted) break;
        final text = chunk.text;
        if (text.isEmpty) continue;

        setState(() {
          _chunkCount++;
        });

        if (_presentationPacing) {
          // Break into smaller rhythmic units (words / punctuation) for stage visibility
          final segments = text.split(RegExp(r'(?<=\s|\n)'));
          for (final segment in segments) {
            if (!mounted || !_isGenerating) break;
            setState(() {
              _answer += segment;
              _tokenCount++;
            });
            _scrollToBottom();
            // Pacing delay: slight pause on punctuation for organic natural cadence
            final isPunctuation = segment.contains(RegExp(r'[.,!?:;]'));
            final delay = isPunctuation
                ? (_typingSpeedMs * 2.2).toInt()
                : _typingSpeedMs.toInt();
            await Future.delayed(Duration(milliseconds: delay));
          }
        } else {
          // Raw stream throughput
          setState(() {
            _answer += text;
            _tokenCount += text.split(' ').length;
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      setState(() {
        _answer += '\n\n❌ Error streaming from model: $e';
      });
    } finally {
      _stopwatch?.stop();
      _timer?.cancel();
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('2. Streaming Tokens into UI'),
        actions: [
          // Live toggle for Presentation Mode
          Row(
            children: [
              Icon(
                Icons.slow_motion_video,
                size: 20,
                color: _presentationPacing
                    ? colorScheme.primary
                    : colorScheme.outline,
              ),
              const SizedBox(width: 4),
              Text(
                'Stage Pacing',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: _presentationPacing
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              Switch(
                value: _presentationPacing,
                onChanged: _isGenerating
                    ? null
                    : (val) => setState(() => _presentationPacing = val),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 850),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Prompt Input Card
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText:
                              'Ask Gemini anything to see real-time streaming...',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: colorScheme.surface,
                          prefixIcon: const Icon(Icons.psychology_outlined),
                        ),
                        onSubmitted: (_) => _askAiStream(),
                      ),
                      const SizedBox(height: 12),
                      // Preset suggestions for stage demo
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          ActionChip(
                            avatar: const Icon(Icons.bolt, size: 16),
                            label: const Text('Why token streaming?'),
                            onPressed: _isGenerating
                                ? null
                                : () => _askAiStream(
                                      'Explain in 3 concise bullet points why streaming tokens is essential for mobile UI UX.',
                                    ),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.flutter_dash, size: 16),
                            label: const Text('Flutter + Genkit'),
                            onPressed: _isGenerating
                                ? null
                                : () => _askAiStream(
                                      'How does Genkit Dart connect Gemini streaming directly into Flutter StreamBuilder and setState?',
                                    ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isGenerating ? null : () => _askAiStream(),
                              icon: _isGenerating
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.stream),
                              label: Text(
                                _isGenerating
                                    ? 'Streaming Tokens...'
                                    : 'Ask AI (generateStream)',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Live Stream Status Telemetry Bar
              if (_answer.isNotEmpty || _isGenerating) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _isGenerating
                        ? colorScheme.primaryContainer.withValues(alpha: 0.7)
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isGenerating
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Pulsing Status Dot
                      if (_isGenerating)
                        FadeTransition(
                          opacity: _cursorController,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      else
                        const Icon(Icons.check_circle,
                            color: Colors.green, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        _isGenerating
                            ? 'LIVE STREAMING FROM GEMINI FLASH'
                            : 'STREAM COMPLETED',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          color: _isGenerating
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      // Telemetry Badges
                      Text(
                        'Chunks: $_chunkCount  |  Words: $_tokenCount  |  Time: ${_elapsedSeconds.toStringAsFixed(1)}s',
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Streaming Output Area
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: _answer.isEmpty && !_isGenerating
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.stream_outlined,
                                size: 48,
                                color: colorScheme.outline.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Click "Ask AI" or choose a preset above to watch token streaming live.',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          controller: _scrollController,
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.6,
                                color: colorScheme.onSurface,
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
                                        margin:
                                            const EdgeInsets.only(left: 4),
                                        color: colorScheme.primary,
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
        ),
      ),
    );
  }
}
