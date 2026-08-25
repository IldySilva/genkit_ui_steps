import 'package:flutter/material.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:schemantic/schemantic.dart';

part 'step4_tools.g.dart';

@Schema()
abstract class $ChangeThemeInput {
  String get color;
}

@Schema()
abstract class $NavigateInput {
  String get screen;
}

final navigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(const Step4App());
}

class Step4App extends StatefulWidget {
  const Step4App({super.key});

  @override
  State<Step4App> createState() => Step4AppState();
}

class Step4AppState extends State<Step4App> {
  Color _themeColor = Colors.deepPurple;

  void changeTheme(String color) {
    setState(() {
      _themeColor = Color(int.parse(color.replaceFirst('#', '0xff')));
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Goes AI - Step 4',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _themeColor,
          brightness: _themeColor.computeLuminance() > 0.5
              ? Brightness.light
              : Brightness.dark,
        ),
      ),
      initialRoute: '/home',
      routes: {
        '/home': (context) => Step4Screen(onThemeChanged: changeTheme),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const Center(child: Text('Settings Screen')),
    );
  }
}

class Step4Screen extends StatefulWidget {
  final Function(String) onThemeChanged;

  const Step4Screen({super.key, required this.onThemeChanged});

  @override
  State<Step4Screen> createState() => _Step4ScreenState();
}

class _Step4ScreenState extends State<Step4Screen> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  List<String> _activityLog = [];

  late final Genkit ai;
  late final Tool changeThemeTool;
  late final Tool navigateTool;

  @override
  void initState() {
    super.initState();
    ai = Genkit(
      plugins: [googleAI(apiKey: const String.fromEnvironment('GEMINI_API_KEY', defaultValue: 'YOUR_API_KEY_HERE'))],
    );

    changeThemeTool = ai.defineTool(
      name: 'changeTheme',
      description:
          'Changes the visual theme of the Flutter application. '
          'Use this when the user asks to change the application theme.',
      inputSchema: ChangeThemeInput.$schema,
      fn: (input, _) async {
        widget.onThemeChanged(input.color);
        setState(() {
          _activityLog.add('🔧 changeTheme\ncolor: ${input.color}');
        });
        return 'Theme changed to ${input.color}';
      },
    );

    navigateTool = ai.defineTool(
      name: 'navigateTo',
      description: 'Navigates to another screen in the Flutter application.',
      inputSchema: NavigateInput.$schema,
      fn: (input, _) async {
        switch (input.screen) {
          case 'settings':
            navigatorKey.currentState?.pushNamed('/settings');
            setState(() {
              _activityLog.add('🔧 navigateTo(settings)');
            });
            return 'Navigated to settings';

          case 'home':
            navigatorKey.currentState?.pushNamed('/home');
            setState(() {
              _activityLog.add('🔧 navigateTo(home)');
            });
            return 'Navigated to home';

          default:
            return 'Unknown screen: ${input.screen}';
        }
      },
    );
  }

  Future<void> _askAiTools() async {
    setState(() {
      _isLoading = true;
      _activityLog = ['🤔 Understanding request...'];
    });

    final prompt = _controller.text.isEmpty
        ? 'Make the app dark and gloomy.'
        : _controller.text;

    try {
      await ai.generate(
        model: googleAI.gemini('gemini-3.1-flash-lite'),
        prompt: prompt,
        toolNames: [changeThemeTool.name, navigateTool.name],
      );

      setState(() {
        _activityLog.add('✓ Tool executed');
      });
    } catch (e) {
      setState(() {
        _activityLog.add('Error: $e');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('4. Function Calling')),
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Make it dark and open settings.',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _askAiTools(),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _askAiTools,
                    child: const Text('Run Request'),
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
                    'AI ACTIVITY',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isLoading)
                    const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  ..._activityLog.map(
                    (log) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        log,
                        style: const TextStyle(color: Colors.greenAccent),
                      ),
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
