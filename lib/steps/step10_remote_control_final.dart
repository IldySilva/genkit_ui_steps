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
      _themeColor = Color(int.parse(color.replaceFirst('#', '0xff')));
    });
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
        '/home': (context) => FinalDemoScreen(onThemeChanged: changeTheme),
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

  const FinalDemoScreen({super.key, required this.onThemeChanged});

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
          _activityLog.add('✓ changeTheme(${input.color})');
        });
        return ToolResult.response('Theme changed to ${input.color}');
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
              _activityLog.add('✓ navigateTo(settings)');
            });
            return ToolResult.response('Navigated to settings');

          case 'home':
            navigatorKey.currentState?.pushNamed('/home');
            setState(() {
              _activityLog.add('✓ navigateTo(home)');
            });
            return ToolResult.response('Navigated to home');

          default:
            return ToolResult.response('Unknown screen: ${input.screen}');
        }
      },
    );
  }

  Future<void> _runCommand() async {
    if (_controller.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _activityLog = ['🤔 Understanding request...'];
    });

    try {
      await ai.generate(
        model: googleAI.gemini('gemini-3.1-flash-lite'),
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
        toolNames: [changeThemeTool.name, navigateTool.name],
      );
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
      body: Center(
        child: Container(
          width: 600,
          padding: const EdgeInsets.all(32.0),
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
              const SizedBox(height: 32),
              const Text(
                'What do you want to do?',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: '"Make this dark and open settings"',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _runCommand(),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _runCommand,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  '[ RUN ]',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 32),
              if (_activityLog.isNotEmpty) ...[
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
    );
  }
}
