import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const Step4App());
}

Color _parseColor(String raw) {
  final s = raw.trim().toLowerCase();
  if (s.contains('dark') ||
      s.contains('escuro') ||
      s.contains('black') ||
      s.contains('preto') ||
      s.contains('gloomy')) {
    return const Color(0xFF1E1E1E);
  }
  if (s.contains('light') ||
      s.contains('claro') ||
      s.contains('white') ||
      s.contains('branco')) {
    return Colors.blueGrey.shade100;
  }
  if (s.contains('matrix') || s.contains('cyberpunk') || s.contains('hacker')) {
    return const Color(0xFF00FF41);
  }
  if (s.contains('blue') || s.contains('azul')) {
    return Colors.blue;
  }
  if (s.contains('green') || s.contains('verde')) {
    return Colors.green;
  }
  if (s.contains('red') || s.contains('vermelho')) {
    return Colors.red;
  }
  if (s.contains('purple') || s.contains('roxo')) {
    return Colors.deepPurple;
  }
  if (s.contains('orange') || s.contains('laranja')) {
    return Colors.orange;
  }
  if (s.contains('yellow') || s.contains('amarelo')) {
    return Colors.amber;
  }
  if (s.contains('pink') || s.contains('rosa')) {
    return Colors.pink;
  }
  if (s.contains('teal')) {
    return Colors.teal;
  }

  // Parse Hex code (#121212, #123, 0xff121212, etc.)
  try {
    String hex = s.replaceAll('#', '').replaceAll('0x', '');
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

class Step4App extends StatefulWidget {
  const Step4App({super.key});

  @override
  State<Step4App> createState() => Step4AppState();
}

class Step4AppState extends State<Step4App> {
  Color _themeColor = Colors.deepPurple;

  void changeTheme(String color) {
    setState(() {
      _themeColor = _parseColor(color);
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.settings, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Settings Screen',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Navigated here via AI Function Calling!'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Home'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
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
      plugins: [
        googleAI(
          apiKey: dotenv.env['GEMINI_API_KEY'] ??
              const String.fromEnvironment('GEMINI_API_KEY'),
        ),
      ],
    );

    changeThemeTool = ai.defineTool(
      name: 'changeTheme',
      description:
          'Changes the visual theme of the Flutter application. '
          'Accepts a hex color (e.g. #1E1E1E) or a color name (e.g. "dark", "blue", "green", "matrix").',
      inputSchema: ChangeThemeInput.$schema,
      fn: (input, _) async {
        widget.onThemeChanged(input.color);
        setState(() {
          _activityLog.add('[Tool] changeTheme: ${input.color}');
        });
        return ToolResult.response('Theme changed to ${input.color}');
      },
    );

    navigateTool = ai.defineTool(
      name: 'navigateTo',
      description:
          'Navigates to another screen in the Flutter application ("settings" or "home").',
      inputSchema: NavigateInput.$schema,
      fn: (input, _) async {
        final target = input.screen.trim().toLowerCase().replaceAll('/', '');
        if (target.contains('setting') || target.contains('configura')) {
          navigatorKey.currentState?.pushNamed('/settings');
          setState(() {
            _activityLog.add('[Tool] navigateTo(settings)');
          });
          return ToolResult.response('Navigated to settings');
        } else if (target.contains('home') ||
            target.contains('início') ||
            target.contains('inicio')) {
          navigatorKey.currentState?.pushNamed('/home');
          setState(() {
            _activityLog.add('[Tool] navigateTo(home)');
          });
          return ToolResult.response('Navigated to home');
        } else {
          setState(() {
            _activityLog.add('[Tool] navigateTo unknown: ${input.screen}');
          });
          return ToolResult.response(
              'Unknown screen: ${input.screen}. Available screens: "settings", "home".');
        }
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _askAiTools([String? customPrompt]) async {
    final prompt = customPrompt ??
        (_controller.text.trim().isEmpty
            ? 'Make the app dark and gloomy and open settings.'
            : _controller.text.trim());

    if (customPrompt != null) {
      _controller.text = customPrompt;
    }

    setState(() {
      _isLoading = true;
      _activityLog = ['[AI] Understanding request: "$prompt"'];
    });

    try {
      final response = await ai.generate(
        model: googleAI.gemini('gemini-2.5-flash'),
        system: '''You are an AI assistant controlling a Flutter application.
You have access to tools: changeTheme and navigateTo.
When the user asks to change the theme, appearance, or color, call changeTheme with a hex color (e.g. #1E1E1E for dark, #00FF41 for matrix, #2196F3 for blue).
When the user asks to open or navigate to a screen, call navigateTo with "settings" or "home".
You can call both tools if requested.''',
        prompt: prompt,
        tools: [changeThemeTool, navigateTool],
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException(
            'Request timed out. Please check your network connection.'),
      );

      if (response.finishReason == 'failed') {
        setState(() {
          _activityLog.add(
              '[Warning] ${response.finishMessage ?? "Model execution failed"}');
        });
      } else {
        if (response.text.isNotEmpty) {
          setState(() {
            _activityLog.add('[Response] ${response.text}');
          });
        }
        setState(() {
          _activityLog.add('[Done] Request completed');
        });
      }
    } catch (e) {
      setState(() {
        _activityLog.add('[Error] $e');
      });
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
      appBar: AppBar(title: const Text('4. Function Calling')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 650;

          final mainContent = Padding(
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
                        Icon(Icons.touch_app, color: Colors.deepPurple),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'AI as a Remote Control: The model interprets natural language intent and invokes strongly typed Flutter tools.',
                            style: TextStyle(fontSize: 13),
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
                      label: const Text('Dark & Settings'),
                      onPressed: _isLoading
                          ? null
                          : () => _askAiTools(
                              'Make it dark and gloomy and open settings.'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.palette, size: 16),
                      label: const Text('Matrix Green'),
                      onPressed: _isLoading
                          ? null
                          : () => _askAiTools(
                              'Change theme to matrix cyberpunk green.'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.settings, size: 16),
                      label: const Text('Open Settings'),
                      onPressed: _isLoading
                          ? null
                          : () => _askAiTools('Navigate to settings screen.'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.light_mode, size: 16),
                      label: const Text('Blue Theme'),
                      onPressed: _isLoading
                          ? null
                          : () =>
                              _askAiTools('Change theme color to ocean blue.'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'e.g. Make it dark and open settings.',
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
                  onSubmitted: (_) => _askAiTools(),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  onPressed: _isLoading ? null : () => _askAiTools(),
                  label: const Text('Run Request'),
                ),
              ],
            ),
          );

          final activityPanel = Container(
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
                const SizedBox(height: 12),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12.0),
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                Expanded(
                  child: ListView(
                    children: _activityLog
                        .map(
                          (log) => Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              log,
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          );

          if (isMobile) {
            return Column(
              children: [
                Expanded(
                  flex: 5,
                  child: SingleChildScrollView(child: mainContent),
                ),
                Expanded(
                  flex: 4,
                  child: activityPanel,
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 2, child: mainContent),
              Expanded(flex: 1, child: activityPanel),
            ],
          );
        },
      ),
    );
  }
}
