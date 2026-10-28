import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:schemantic/schemantic.dart';

part 'step3_structured.g.dart';

@Schema()
abstract class $ThemeCommand {
  String get color;
  String get mood;
}

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
  runApp(const Step3App());
}

class Step3App extends StatelessWidget {
  const Step3App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Goes AI - Step 3',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const Step3Screen(),
    );
  }
}

class Step3Screen extends StatefulWidget {
  const Step3Screen({super.key});

  @override
  State<Step3Screen> createState() => _Step3ScreenState();
}

class _Step3ScreenState extends State<Step3Screen> {
  final TextEditingController _controller = TextEditingController();
  ThemeCommand? _themeCommand;
  bool _isLoading = false;

  Future<void> _askAiStructured() async {
    setState(() {
      _isLoading = true;
      _themeCommand = null;
    });

    final prompt = _controller.text.isEmpty
        ? 'Make the app dark and gloomy.'
        : _controller.text;

    final response = await ai.generate(
      model: googleAI.gemini('gemini-3.1-flash-lite'),
      prompt:
          '''
The user wants to customize the application.

User request:
"$prompt"

Return the appropriate theme configuration.
''',
      outputSchema: ThemeCommand.$schema,
    );

    setState(() {
      _themeCommand = response.output;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('3. Structured Output')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Make the app dark and gloomy.',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _askAiStructured(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _askAiStructured,
              child: const Text('Ask AI (Structured)'),
            ),
            const SizedBox(height: 32),
            if (_isLoading) const CircularProgressIndicator(),
            if (!_isLoading && _themeCommand != null) ...[
              const Text(
                'Structured Output Data:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Color: ${_themeCommand!.color}'),
                      const SizedBox(height: 8),
                      Text('Mood: ${_themeCommand!.mood}'),
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
