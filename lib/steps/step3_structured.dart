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

Color _parseColor(String raw) {
  try {
    String hex = raw.trim().toLowerCase().replaceAll('#', '').replaceAll('0x', '');
    if (hex.length == 3) {
      hex = hex.split('').map((c) => '$c$c').join();
    }
    if (hex.length == 6) {
      hex = 'ff$hex';
    }
    if (hex.length == 8) {
      return Color(int.parse(hex, radix: 16));
    }
  } catch (_) {}
  return Colors.deepPurple;
}

class Step3App extends StatelessWidget {
  const Step3App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Goes AI - Step 3',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _askAiStructured([String? customPrompt]) async {
    final prompt = customPrompt ??
        (_controller.text.trim().isEmpty
            ? 'Make the app dark and gloomy.'
            : _controller.text.trim());

    if (customPrompt != null) {
      _controller.text = customPrompt;
    }

    setState(() {
      _isLoading = true;
      _themeCommand = null;
    });

    try {
      final response = await ai.generate(
        model: googleAI.gemini('gemini-2.5-flash'),
        prompt: '''
The user wants to customize the application.

User request:
"$prompt"

Return the appropriate theme configuration with an exact hex color (e.g. #1E1E1E) and mood descriptor.
''',
        outputSchema: ThemeCommand.$schema,
      );

      if (mounted) {
        setState(() {
          _themeCommand = response.output;
        });
      }
    } catch (_) {
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
      appBar: AppBar(title: const Text('3. Structured Output')),
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
                    Icon(Icons.data_object, color: Colors.deepPurple),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Structured Output (Schemantic)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Constrains LLM output strictly to a strongly-typed Dart schema (ThemeCommand) with 0 JSON parsing errors.',
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
                  avatar: const Icon(Icons.dark_mode, size: 16),
                  label: const Text('Dark & Gloomy'),
                  onPressed: _isLoading
                      ? null
                      : () => _askAiStructured('Make the app dark and gloomy.'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.palette, size: 16),
                  label: const Text('Cyberpunk Neon'),
                  onPressed: _isLoading
                      ? null
                      : () => _askAiStructured(
                          'Style the application with a vibrant cyberpunk neon aesthetic.'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.water_drop, size: 16),
                  label: const Text('Ocean Breeze'),
                  onPressed: _isLoading
                      ? null
                      : () => _askAiStructured(
                          'Give me a refreshing and serene ocean turquoise theme.'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.forest, size: 16),
                  label: const Text('Autumn Forest'),
                  onPressed: _isLoading
                      ? null
                      : () => _askAiStructured(
                          'A cozy minimal amber forest evening mood.'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'e.g. Make the app dark and gloomy.',
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
              onSubmitted: (_) => _askAiStructured(),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow),
              onPressed: _isLoading ? null : () => _askAiStructured(),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              label: Text(_isLoading
                  ? 'Generating structured data...'
                  : 'Ask AI (Structured)'),
            ),
            if (_isLoading) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
            if (!_isLoading && _themeCommand != null) ...[
              const SizedBox(height: 20),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Structured ThemeCommand Object',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Type-Safe',
                              style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor:
                              _parseColor(_themeCommand!.color),
                          radius: 20,
                        ),
                        title: Text(
                          'Color: ${_themeCommand!.color}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Mood: ${_themeCommand!.mood}',
                          style: const TextStyle(fontSize: 13),
                        ),
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
