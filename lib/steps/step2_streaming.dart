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
      title: 'Flutter Goes AI - Step 2',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
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

class _Step2ScreenState extends State<Step2Screen> {
  final TextEditingController _controller = TextEditingController();
  String _answer = '';
  bool _isGenerating = false;

  Future<void> _askAiStream() async {
    setState(() {
      _answer = '';
      _isGenerating = true;
    });

    final prompt = _controller.text.isEmpty
        ? 'Explain why Flutter is good for building AI applications.'
        : _controller.text;

    final stream = ai.generateStream(
      model: googleAI.gemini('gemini-3.1-flash-lite'),
      prompt: prompt,
    );

    await for (final chunk in stream) {
      setState(() {
        _answer += chunk.text;
      });
    }

    setState(() {
      _isGenerating = false;
    });
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
              const Text(
                'AI Response:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(child: SingleChildScrollView(child: Text(_answer))),
            ],
          ],
        ),
      ),
    );
  }
}
