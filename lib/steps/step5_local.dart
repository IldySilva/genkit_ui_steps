import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_llamadart/genkit_llamadart.dart';
import 'package:schemantic/schemantic.dart';

part 'step5_local.g.dart';

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
  runApp(const Step5App());
}

class Step5App extends StatefulWidget {
  const Step5App({super.key});

  @override
  State<Step5App> createState() => Step5AppState();
}

class Step5AppState extends State<Step5App> {
  Color _themeColor = Colors.deepPurple;

  void changeTheme(String color) {
    setState(() {
      _themeColor = Color(
        int.parse(color.replaceFirst('#', '0xff')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Goes AI - Step 5 (Local Model)',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _themeColor,
          brightness: _themeColor.computeLuminance() > 0.5 ? Brightness.light : Brightness.dark,
        ),
      ),
      initialRoute: '/home',
      routes: {
        '/home': (context) => Step5Screen(onThemeChanged: changeTheme),
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

class Step5Screen extends StatefulWidget {
  final Function(String) onThemeChanged;

  const Step5Screen({super.key, required this.onThemeChanged});

  @override
  State<Step5Screen> createState() => _Step5ScreenState();
}

class _Step5ScreenState extends State<Step5Screen> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  List<String> _activityLog = [];

  LlamaDartPlugin? _plugin;
  Genkit? _ai;
  Tool? _changeThemeTool;
  Tool? _navigateTool;
  String? _modelPath;

  String? _resolveModelPath() {
    const relativePath = 'assets/Qwen3.5-0.8B-IQ4_NL.gguf';

    final candidates = <String>[
      relativePath,
      '${Directory.current.path}/$relativePath',
    ];

    final pwd = Platform.environment['PWD'];
    if (pwd != null) {
      candidates.add('$pwd/$relativePath');
    }

    try {
      final exe = File(Platform.resolvedExecutable);
      final contents = exe.parent.parent;
      candidates.addAll([
        '${contents.path}/Frameworks/App.framework/Versions/A/Resources/flutter_assets/$relativePath',
        '${contents.path}/Frameworks/App.framework/Resources/flutter_assets/$relativePath',
        '${contents.path}/Resources/flutter_assets/$relativePath',
      ]);

      Directory? cur = exe.parent;
      for (int i = 0; i < 10 && cur != null; i++) {
        candidates.add('${cur.path}/$relativePath');
        final parent = cur.parent;
        if (parent.path == cur.path) break;
        cur = parent;
      }
    } catch (_) {}

    try {
      Directory? curDir = Directory.current;
      for (int i = 0; i < 6 && curDir != null; i++) {
        candidates.add('${curDir.path}/$relativePath');
        final parent = curDir.parent;
        if (parent.path == curDir.path) break;
        curDir = parent;
      }
    } catch (_) {}

    for (final candidate in candidates) {
      try {
        final file = File(candidate);
        if (file.existsSync()) {
          return file.resolveSymbolicLinksSync();
        }
      } catch (_) {}
    }

    return null;
  }

  void _ensureInitialized() {
    if (_ai != null) return;
    final resolved = _resolveModelPath();
    if (resolved == null) return;
    _modelPath = resolved;

    _plugin = llamaDart(
      models: [
        LlamaModelDefinition(
          name: 'local-qwen',
          modelPath: _modelPath!,
          modelParams: const ModelParams(
            contextSize: 2048,
          ),
          supportsTools: true,
        ),
      ],
    );

    _ai = Genkit(
      plugins: [
        _plugin!,
      ],
    );

    _changeThemeTool = _ai!.defineTool(
      name: 'changeTheme',
      description:
          'Changes the visual theme of the Flutter application. Accepts a hex color string like #121212.',
      inputSchema: ChangeThemeInput.$schema,
      fn: (input, _) async {
        widget.onThemeChanged(input.color);
        setState(() {
          _activityLog.add('🔧 changeTheme\ncolor: ${input.color}');
        });
        return ToolResult.response('Theme changed to ${input.color}');
      },
    );

    _navigateTool = _ai!.defineTool(
      name: 'navigateTo',
      description: 'Navigates to another screen in the Flutter application ("settings" or "home").',
      inputSchema: NavigateInput.$schema,
      fn: (input, _) async {
        switch (input.screen) {
          case 'settings':
            navigatorKey.currentState?.pushNamed('/settings');
            setState(() {
              _activityLog.add('🔧 navigateTo(settings)');
            });
            return ToolResult.response('Navigated to settings');

          case 'home':
            navigatorKey.currentState?.pushNamed('/home');
            setState(() {
              _activityLog.add('🔧 navigateTo(home)');
            });
            return ToolResult.response('Navigated to home');

          default:
            return ToolResult.response('Unknown screen: ${input.screen}');
        }
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _ensureInitialized();
    if (_modelPath != null) {
      _activityLog.add('✅ Found local model: ${_modelPath!.split('/').last}');
    } else {
      _activityLog.add('⚠️ Searching for local GGUF model in app assets...');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    if (_plugin != null) {
      unawaited(_plugin!.dispose());
    }
    if (_ai != null) {
      unawaited(_ai!.shutdown());
    }
    super.dispose();
  }

  Future<void> _askAiTools() async {
    _ensureInitialized();

    if (_ai == null || _modelPath == null) {
      setState(() {
        _isLoading = false;
        _activityLog = [
          '❌ Local model file not found.',
          'ℹ️ Checked candidate paths for "assets/Qwen3.5-0.8B-IQ4_NL.gguf".',
          'ℹ️ Ensure the file exists in the project assets/ folder.',
        ];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _activityLog = ['🤔 Loading local model & running on-device inference...'];
    });

    final prompt = _controller.text.isEmpty
        ? 'Change theme to dark gloomy #1a1a1a.'
        : _controller.text;

    try {
      final response = await _ai!.generate(
        model: llamaDart.model('local-qwen'),
        system: '''You are an AI assistant controlling a Flutter app.
You have access to tools: changeTheme and navigateTo.
When the user asks to change theme or appearance, call changeTheme with a hex color.
When the user asks to open settings or home, call navigateTo.''',
        prompt: prompt,
        tools: [
          _changeThemeTool!,
          _navigateTool!,
        ],
      ).timeout(
        const Duration(seconds: 25),
        onTimeout: () => throw TimeoutException('Local model execution timed out after 25s.'),
      );

      if (response.text.isNotEmpty) {
        setState(() {
          _activityLog.add('💬 ${response.text}');
          _activityLog.add('✓ On-device execution completed');
        });
      } else {
        setState(() {
          _activityLog.add('✓ On-device execution completed');
        });
      }
    } catch (e) {
      setState(() {
        _activityLog.add('❌ Error: $e');
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
        title: const Text('5. Local AI (Qwen 3.5 0.8B via genkit_llamadart)'),
      ),
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: Padding(
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
                          Icon(Icons.offline_bolt, color: Colors.amber),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Offline / On-Device: Running Qwen 3.5 0.8B (IQ4_NL GGUF) via llama.cpp + Metal. No API keys or cloud calls required.',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Change theme to dark gloomy #1a1a1a.',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _askAiTools(),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: _isLoading ? null : _askAiTools,
                    label: const Text('Run Request (Local Model)'),
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
                  const Text('AI ACTIVITY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (_isLoading) const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  ..._activityLog.map((log) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(log, style: const TextStyle(color: Colors.greenAccent)),
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
