import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:genkit/experimental.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:schemantic/schemantic.dart';

part 'step8_agent_interrupt.g.dart';

@Schema()
abstract class $ChangeThemeInput {
  String get color;
}

@Schema()
abstract class $ResetSettingsInput {
  String get reason;
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
  runApp(const Step8App());
}

class Step8App extends StatefulWidget {
  const Step8App({super.key});

  @override
  State<Step8App> createState() => Step8AppState();
}

class Step8AppState extends State<Step8App> {
  Color _themeColor = Colors.deepPurple;

  void changeTheme(String color) {
    setState(() {
      _themeColor = _parseColor(color);
    });
  }

  void resetTheme() {
    setState(() {
      _themeColor = Colors.deepPurple;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Goes AI - Step 8 (Agents & Interrupts)',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _themeColor,
          brightness: _themeColor.computeLuminance() > 0.5
              ? Brightness.light
              : Brightness.dark,
        ),
      ),
      home: Step8Screen(
        onThemeChanged: changeTheme,
        onResetTheme: resetTheme,
      ),
    );
  }
}

class Step8Screen extends StatefulWidget {
  final Function(String) onThemeChanged;
  final VoidCallback onResetTheme;

  const Step8Screen({
    super.key,
    required this.onThemeChanged,
    required this.onResetTheme,
  });

  @override
  State<Step8Screen> createState() => _Step8ScreenState();
}

class _Step8ScreenState extends State<Step8Screen> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  final List<String> _activityLog = [];

  late final Genkit ai;
  late final dynamic assistantAgent;
  late dynamic _currentChat;

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
      model: googleAI.gemini(dotenv.env['GEMINI_MODEL'] ??
          const String.fromEnvironment('GEMINI_MODEL',
              defaultValue: 'gemini-2.5-flash-lite')),
    );

    final changeThemeTool = ai.defineTool(
      name: 'changeTheme',
      description:
          'Changes visual theme color for normal styling requests. Accepts hex or color name.',
      inputSchema: ChangeThemeInput.$schema,
      fn: (input, _) async {
        widget.onThemeChanged(input.color);
        if (mounted) {
          setState(() {
            _activityLog.add('[Tool] changeTheme(${input.color})');
          });
        }
        return ToolResult.response('Theme changed to ${input.color}');
      },
    );

    final resetSettingsTool = ai.defineTool(
      name: 'resetSettings',
      description:
          'DANGEROUS ACTION: Resets all application settings and data to defaults. '
          'Requires human confirmation before proceeding.',
      inputSchema: ResetSettingsInput.$schema,
      fn: (input, _) async {
        return ToolResult.interrupt({
          'action': 'resetSettings',
          'reason': input.reason,
        });
      },
    );

    assistantAgent = ai.defineAgent(
      name: 'assistantAgent',
      system:
          'You are a Flutter controller agent. '
          'Use changeTheme for style requests. '
          'Use resetSettings when the user asks to reset, wipe, or restore defaults. '
          'Be aware resetSettings requires user approval.',
      tools: [changeThemeTool, resetSettingsTool],
      store: InMemorySessionStore(),
    );

    _currentChat = assistantAgent.chat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _askAgent([String? customPrompt]) async {
    final text = customPrompt ?? _controller.text.trim();
    if (text.isEmpty) return;

    if (customPrompt != null) {
      _controller.text = customPrompt;
    }

    setState(() {
      _isLoading = true;
      _activityLog.add('[Agent] Evaluating intention: "$text"');
    });

    try {
      final res = await _currentChat.send(text: text);

      // Check if the agent hit an interrupt
      if (res.interrupts.isNotEmpty) {
        final interrupt = res.interrupts.first;
        setState(() {
          _activityLog
              .add('[Interrupt] ${interrupt.name} requires human approval');
        });

        if (mounted) {
          final approved = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              icon: const Icon(Icons.shield_outlined,
                  size: 40, color: Colors.amber),
              title: const Text('Security Authorization'),
              content: Text(
                'The AI Agent is requesting permission to execute a privileged action: "${interrupt.name}".\n\n'
                'Reason: ${interrupt.input['reason'] ?? interrupt.input}\n\n'
                'Do you authorize this action?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child:
                      const Text('Deny', style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Approve Action'),
                ),
              ],
            ),
          );

          if (approved == true) {
            setState(() {
              _activityLog.add('[User] Approved. Resuming agent turn...');
            });
            widget.onResetTheme();

            final resumeRes = await _currentChat.resume(
              respond: [
                interrupt.respond({
                  'approved': true,
                  'feedback': 'Action approved by user.'
                }),
              ],
            );
            setState(() {
              _activityLog.add('[Done] Action executed: ${resumeRes.text}');
            });
          } else {
            setState(() {
              _activityLog.add('[Denied] User denied action.');
            });
            final resumeRes = await _currentChat.resume(
              respond: [
                interrupt.respond({
                  'approved': false,
                  'feedback': 'User rejected action.'
                }),
              ],
            );
            setState(() {
              _activityLog.add('[Agent] Acknowledgment: ${resumeRes.text}');
            });
          }
        }
      } else {
        setState(() {
          _activityLog.add('[Done] Agent completed turn: ${res.text}');
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

  Color _getLogColor(String log) {
    if (log.contains('[Interrupt]')) return Colors.amberAccent;
    if (log.contains('[User]')) return Colors.cyanAccent;
    if (log.contains('[Denied]')) return Colors.redAccent;
    if (log.contains('[Done]')) return Colors.greenAccent;
    if (log.contains('[Tool]')) return Colors.tealAccent;
    if (log.contains('[Error]')) return Colors.redAccent;
    return Colors.white70;
  }

  Widget _buildActivityPanel({bool isExpanded = false}) {
    final content = Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'AGENT ACTIVITY',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  fontSize: 12,
                ),
              ),
              if (_activityLog.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep,
                      color: Colors.white70, size: 18),
                  tooltip: 'Clear activity log',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(() => _activityLog.clear()),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_isLoading) ...[
            const ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(2)),
              child: LinearProgressIndicator(
                color: Colors.greenAccent,
                backgroundColor: Colors.white12,
                minHeight: 3,
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (isExpanded)
            Expanded(
              child: ListView.builder(
                itemCount: _activityLog.length,
                itemBuilder: (context, index) {
                  final log = _activityLog[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Text(
                      log,
                      style: TextStyle(
                        color: _getLogColor(log),
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _activityLog.isEmpty
                  ? [
                      const Text(
                        'No agent events yet. Try a quick prompt or type a command.',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ]
                  : _activityLog.map((log) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Text(
                          log,
                          style: TextStyle(
                            color: _getLogColor(log),
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      );
                    }).toList(),
            ),
        ],
      ),
    );

    return isExpanded ? Expanded(child: content) : content;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('7. Agent Interrupts'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 650;

          final infoCard = Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Icon(Icons.security, color: Colors.deepPurple),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Human-in-the-Loop Interrupts',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Privileged tools (e.g. resetSettings) trigger an interrupt pause, allowing the user to Approve or Deny before continuing.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );

          final quickPrompts = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                    avatar: const Icon(Icons.warning_amber,
                        size: 16, color: Colors.amber),
                    label: const Text('Reset All Settings'),
                    onPressed: _isLoading
                        ? null
                        : () => _askAgent(
                            'Reset all application settings and data to default.'),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.palette, size: 16),
                    label: const Text('Matrix Green'),
                    onPressed: _isLoading
                        ? null
                        : () => _askAgent(
                            'Change visual theme to matrix cyberpunk green.'),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.dark_mode, size: 16),
                    label: const Text('Dark Navy'),
                    onPressed: _isLoading
                        ? null
                        : () => _askAgent(
                            'Change visual theme to dark navy blue.'),
                  ),
                ],
              ),
            ],
          );

          final promptInput = TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText:
                  'Try: "Reset all application data" or "Make it dark blue"',
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
            onSubmitted: (_) => _isLoading ? null : _askAgent(),
          );

          final sendButton = ElevatedButton.icon(
            icon: const Icon(Icons.send),
            onPressed: _isLoading ? null : () => _askAgent(),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            label: Text(_isLoading ? 'Agent thinking...' : 'Send to Agent'),
          );

          if (isMobile) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  infoCard,
                  const SizedBox(height: 12),
                  quickPrompts,
                  const SizedBox(height: 16),
                  promptInput,
                  const SizedBox(height: 12),
                  sendButton,
                  const SizedBox(height: 16),
                  _buildActivityPanel(isExpanded: false),
                ],
              ),
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      infoCard,
                      const SizedBox(height: 12),
                      quickPrompts,
                      const SizedBox(height: 16),
                      promptInput,
                      const SizedBox(height: 12),
                      sendButton,
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Container(
                  color: Colors.black87,
                  padding: const EdgeInsets.all(16.0),
                  child: _buildActivityPanel(isExpanded: true),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
