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
      title: 'Flutter Goes AI - Step 1',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
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

  Future<void> _askAi() async {
    setState(() {
      _isLoading = true;
    });

    final response = await ai.generate(
      model: googleAI.gemini('gemini-3.1-flash-lite'),
      prompt: _controller.text.isEmpty
          ? 'Explain Flutter in one sentence.'
          : _controller.text,
    );

    setState(() {
      _answer = response.text;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('1. Basic AI')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Explain Flutter in one sentence.',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _askAi(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _askAi,
              child: const Text('Ask AI'),
            ),
            const SizedBox(height: 32),
            if (_isLoading) const CircularProgressIndicator(),
            if (!_isLoading && _answer.isNotEmpty) ...[
              const Text(
                'AI Response:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(_answer),
            ],
          ],
        ),
      ),
    );
  }
}
