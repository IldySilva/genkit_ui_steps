import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:schemantic/schemantic.dart';

part 'step10_remote_control_final.g.dart';

@Schema()
abstract class $ChangeThemeInput {
  String get color;
}

@Schema()
abstract class $NavigateInput {
  String get screen;
}

final navigatorKey = GlobalKey<NavigatorState>();

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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const FinalDemoApp());
}

class FinalDemoApp extends StatefulWidget {
  const FinalDemoApp({super.key});

  @override
  State<FinalDemoApp> createState() => FinalDemoAppState();
}

class FinalDemoAppState extends State<FinalDemoApp> {
  Color _themeColor = Colors.deepPurple;

  void changeTheme(String color) {
    setState(() {
      _themeColor = _parseColor(color);
    });
  }

  void navigateTo(String screen) {
    final target = screen.trim().toLowerCase().replaceAll('/', '');
    if (target.contains('setting') || target.contains('configura')) {
      navigatorKey.currentState?.pushNamed('/settings');
    } else if (target.contains('home') ||
        target.contains('início') ||
        target.contains('inicio')) {
      navigatorKey.currentState?.pushNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Goes AI - Step 10 (Master Remote Control)',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _themeColor,
          brightness: _themeColor.computeLuminance() > 0.5
              ? Brightness.light
              : Brightness.dark,
        ),
        useMaterial3: true,
      ),
      initialRoute: '/home',
      routes: {
        '/home': (context) => FinalDemoScreen(
              onThemeChanged: changeTheme,
              onNavigate: navigateTo,
            ),
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
      body: const Center(
        child: Text('Settings Screen', style: TextStyle(fontSize: 24)),
      ),
    );
  }
}

class FinalDemoScreen extends StatefulWidget {
  final Function(String) onThemeChanged;
  final Function(String) onNavigate;

  const FinalDemoScreen({
    super.key,
    required this.onThemeChanged,
    required this.onNavigate,
  });

  @override
  State<FinalDemoScreen> createState() => _FinalDemoScreenState();
}

class _FinalDemoScreenState extends State<FinalDemoScreen> {
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
          'Use this when the user asks to change the application theme.',
      inputSchema: ChangeThemeInput.$schema,
      fn: (input, _) async {
        widget.onThemeChanged(input.color);
        setState(() {
          _activityLog.add('[Tool] changeTheme(${input.color})');
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
        widget.onNavigate(input.screen);
        setState(() {
          _activityLog.add('[Tool] navigateTo(${input.screen})');
        });
        return ToolResult.response('Navigated to ${input.screen}');
      },
    );
  }

  Future<void> _runCommand() async {
    if (_controller.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _activityLog = ['[AI] Understanding request...'];
    });

    try {
      final modelName = dotenv.env['GEMINI_MODEL'] ??
          const String.fromEnvironment('GEMINI_MODEL',
              defaultValue: 'gemini-2.5-flash-lite');
      final response = await ai.generate(
        model: googleAI.gemini(modelName),
        prompt:
            '''
You are controlling a Flutter application.

You have access to tools that can change the theme
and navigate between screens.

When the user asks to change the visual appearance,
use the changeTheme tool.

When the user asks to open another screen,
use the navigateTo tool.

User request:
${_controller.text}
''',
        tools: [changeThemeTool, navigateTool],
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Request timed out. Please check your network connection.'),
      );

      if (response.finishReason == 'failed') {
        setState(() {
          _activityLog.add('[Warning] ${response.finishMessage ?? "Model execution failed"}');
        });
      } else {
        setState(() {
          _activityLog.add('[Done] Request completed');
        });
      }
    } catch (e) {
      setState(() {
        _activityLog.add('[Error] $e');
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
      appBar: AppBar(
        title: const Text('10. Remote Control Final'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'FLUTTER GOES AI',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'What do you want to do?',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'e.g. "Make this dark and open settings"',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _runCommand(),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _runCommand,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              '[ RUN ]',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                    if (_activityLog.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'AI Activity',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _activityLog
                              .map(
                                (log) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4.0),
                                  child: Text(
                                    log,
                                    style: const TextStyle(fontFamily: 'monospace'),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
