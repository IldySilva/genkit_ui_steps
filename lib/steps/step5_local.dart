import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
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
      _themeColor = _parseColor(color);
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
          brightness: _themeColor.computeLuminance() > 0.5
              ? Brightness.light
              : Brightness.dark,
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
            const Text('Navigated here via Local Model Function Calling!'),
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

      // 1. iOS App Bundle: Runner.app/Frameworks/App.framework/flutter_assets/assets/...
      candidates.add(
        '${exe.parent.path}/Frameworks/App.framework/flutter_assets/$relativePath',
      );
      candidates.add(
        '${exe.parent.path}/flutter_assets/$relativePath',
      );

      // 2. macOS App Bundle: genkit.app/Contents/Frameworks/App.framework/Versions/A/Resources/flutter_assets/...
      final contents = exe.parent.parent;
      candidates.addAll([
        '${contents.path}/Frameworks/App.framework/Versions/A/Resources/flutter_assets/$relativePath',
        '${contents.path}/Frameworks/App.framework/Resources/flutter_assets/$relativePath',
        '${contents.path}/Resources/flutter_assets/$relativePath',
      ]);

      // 3. Walk up from executable (useful in local debug runs)
      Directory? cur = exe.parent;
      for (int i = 0; i < 10 && cur != null; i++) {
        candidates.add('${cur.path}/$relativePath');
        final parent = cur.parent;
        if (parent.path == cur.path) break;
        cur = parent;
      }
    } catch (_) {}

    // 4. Walk up from Directory.current
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

  Future<String?> _resolveModelPathAsync() async {
    final direct = _resolveModelPath();
    if (direct != null) return direct;

    // Fallback for Android (where assets are packed inside APK archive):
    try {
      final tempFile =
          File('${Directory.systemTemp.path}/Qwen3.5-0.8B-IQ4_NL.gguf');
      if (tempFile.existsSync() && tempFile.lengthSync() > 100000000) {
        return tempFile.path;
      }
      final byteData =
          await rootBundle.load('assets/Qwen3.5-0.8B-IQ4_NL.gguf');
      final buffer = byteData.buffer;
      await tempFile.writeAsBytes(
        buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
        flush: true,
      );
      return tempFile.path;
    } catch (_) {}

    return null;
  }

  Future<void> _ensureInitialized() async {
    if (_ai != null) return;
    var resolved = _resolveModelPath();
    resolved ??= await _resolveModelPathAsync();
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

    _navigateTool = _ai!.defineTool(
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
  void initState() {
    super.initState();
    _ensureInitialized().then((_) {
      if (mounted && _modelPath != null) {
        setState(() {
          _activityLog.add(
              '[Model] Found local model: ${_modelPath!.split('/').last}');
        });
      }
    });
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

  Future<void> _askAiTools([String? customPrompt]) async {
    await _ensureInitialized();

    if (_ai == null || _modelPath == null) {
      setState(() {
        _isLoading = false;
        _activityLog = [
          '[Error] Local model file not found.',
          '[Info] Checked iOS/macOS bundle and assets/ folder.',
          '[Info] Please ensure "assets/Qwen3.5-0.8B-IQ4_NL.gguf" is placed in the project assets.',
        ];
      });
      return;
    }

    final prompt = customPrompt ??
        (_controller.text.trim().isEmpty
            ? 'Make the app dark and gloomy and open settings.'
            : _controller.text.trim());

    if (customPrompt != null) {
      _controller.text = customPrompt;
    }

    setState(() {
      _isLoading = true;
      _activityLog = ['[AI] Running on-device inference: "$prompt"'];
    });

    try {
      final response = await _ai!.generate(
        model: llamaDart.model('local-qwen'),
        system: '''You are an AI assistant controlling a Flutter application.
You have access to tools: changeTheme and navigateTo.
When the user asks to change the theme, appearance, or color, call changeTheme with a hex color (e.g. #1E1E1E for dark, #00FF41 for matrix, #2196F3 for blue).
When the user asks to open or navigate to a screen, call navigateTo with "settings" or "home".
You can call both tools if requested.''',
        prompt: prompt,
        tools: [
          _changeThemeTool!,
          _navigateTool!,
        ],
      ).timeout(
        const Duration(seconds: 45),
        onTimeout: () => throw TimeoutException(
            'Local model execution timed out. On-device inference may take longer on initial load.'),
      );

      if (response.text.isNotEmpty) {
        setState(() {
          _activityLog.add('[Response] ${response.text}');
        });
      }
      setState(() {
        _activityLog.add('[Done] On-device execution completed');
      });
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
      appBar: AppBar(
        title: const Text('5. Local AI'),
      ),
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
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        const Icon(Icons.offline_bolt, color: Colors.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Offline / On-Device AI',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _modelPath != null
                                    ? 'Model: ${_modelPath!.split('/').last} (Metal / CPU)'
                                    : 'Locating local model (Qwen 3.5 0.8B)...',
                                style: const TextStyle(fontSize: 12),
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
                          : () =>
                              _askAiTools('Navigate to settings screen.'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.light_mode, size: 16),
                      label: const Text('Ocean Blue'),
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
                  label: Text(_isLoading
                      ? 'Processing on-device...'
                      : 'Run Request (Local Model)'),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'AI ACTIVITY',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_activityLog.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.delete_sweep,
                            color: Colors.white70, size: 20),
                        tooltip: 'Clear activity log',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => setState(() => _activityLog.clear()),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            color: Colors.greenAccent,
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Running local inference...',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
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
