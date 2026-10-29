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
  runApp(const Step1App());
}

class Step1App extends StatelessWidget {
  const Step1App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Goes AI - Step 1',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const Step1Screen(),
    );
  }
}

class Step1Screen extends StatefulWidget {
  const Step1Screen({super.key});

  @override
  State<Step1Screen> createState() => _Step1ScreenState();
}

class _Step1ScreenState extends State<Step1Screen> {
  final TextEditingController _controller = TextEditingController();
  String _answer = '';
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _askAi([String? customPrompt]) async {
    final prompt = customPrompt ??
        (_controller.text.trim().isEmpty
            ? 'Explain Flutter in one punchy sentence.'
            : _controller.text.trim());

    if (customPrompt != null) {
      _controller.text = customPrompt;
    }

    setState(() {
      _isLoading = true;
      _answer = '';
    });

    try {
      final modelName = dotenv.env['GEMINI_MODEL'] ??
          const String.fromEnvironment('GEMINI_MODEL',
              defaultValue: 'gemini-2.5-flash-lite');
      final response = await ai.generate(
        model: googleAI.gemini(modelName),
        prompt: prompt,
      );

      if (mounted) {
        setState(() {
          _answer = response.text;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _answer = 'Error: $e';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('1. Basic AI')),
      body: SingleChildScrollView(
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
                    Icon(Icons.chat_bubble_outline, color: Colors.deepPurple),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Basic AI Generation',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Single-shot string invocation via ai.generate. Simple, but blocks until complete.',
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
                  label: const Text('Explain Flutter'),
                  onPressed: _isLoading
                      ? null
                      : () => _askAi('Explain Flutter in one punchy sentence.'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.hub_outlined, size: 16),
                  label: const Text('What is Genkit?'),
                  onPressed: _isLoading
                      ? null
                      : () => _askAi('What is Google Genkit in simple terms?'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.settings_remote, size: 16),
                  label: const Text('AI as UI Remote'),
                  onPressed: _isLoading
                      ? null
                      : () => _askAi(
                          'Why use AI as an application UI remote control instead of a chatbot?'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'e.g. Explain Flutter in one sentence.',
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
              onSubmitted: (_) => _askAi(),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow),
              onPressed: _isLoading ? null : () => _askAi(),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              label: Text(_isLoading ? 'Generating...' : 'Ask AI'),
            ),
            if (_isLoading) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
            if (!_isLoading && _answer.isNotEmpty) ...[
              const SizedBox(height: 20),
              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'AI Response',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            tooltip: 'Clear response',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => setState(() => _answer = ''),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Text(
                        _answer,
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ],
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
