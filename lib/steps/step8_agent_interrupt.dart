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
      _themeColor = Color(int.parse(color.replaceFirst('#', '0xff')));
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
  List<String> _activityLog = [];

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
      model: googleAI.gemini('gemini-2.5-flash-lite'),
    );

    final changeThemeTool = ai.defineTool(
      name: 'changeTheme',
      description: 'Changes visual theme color for normal styling requests.',
      inputSchema: ChangeThemeInput.$schema,
      fn: (input, _) async {
        widget.onThemeChanged(input.color);
        setState(() {
          _activityLog.add('[Tool] changeTheme(${input.color})');
        });
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
        // Return an interrupt asking for human approval
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

  Future<void> _askAgent() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _activityLog = ['[Agent] Evaluating intention...'];
    });

    try {
      final res = await _currentChat.send(text: text);

      // Check if the agent hit an interrupt
      if (res.interrupts.isNotEmpty) {
        final interrupt = res.interrupts.first;
        setState(() {
          _activityLog.add('[Interrupt] ${interrupt.name} requires human approval');
        });

        // Prompt the user in Flutter with a Dialog
        if (mounted) {
          final approved = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('Security Confirmation'),
              content: Text(
                'The agent is requesting permission to execute: "${interrupt.name}".\n\n'
                'Payload: ${interrupt.input}\n\n'
                'Do you authorize this action?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Deny', style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Approve'),
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
                interrupt.respond({'approved': true, 'feedback': 'Action approved by user.'}),
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
                interrupt.respond({'approved': false, 'feedback': 'User rejected action.'}),
              ],
            );
            setState(() {
              _activityLog.add('Agent acknowledgment: ${resumeRes.text}');
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
      appBar: AppBar(title: const Text('6. Experimental Agents & Interrupts')),
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
                      hintText: 'Try: "Reset all application data" or "Make it dark blue"',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _askAgent(),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _askAgent,
                    child: const Text('Send to Agent'),
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
                    'AGENT ACTIVITY',
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
