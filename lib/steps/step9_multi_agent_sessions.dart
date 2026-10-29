import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:genkit/experimental.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:genkit_middleware/agents.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const Step9App());
}

class Step9App extends StatelessWidget {
  const Step9App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Goes AI - Step 9 (Multi-Agent & Snapshots)',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const Step9Screen(),
    );
  }
}

class Step9Screen extends StatefulWidget {
  const Step9Screen({super.key});

  @override
  State<Step9Screen> createState() => _Step9ScreenState();
}

class _Step9ScreenState extends State<Step9Screen> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  final List<String> _conversationLog = [];
  final List<String> _snapshotHistory = [];

  late final Genkit ai;
  late final dynamic stylistAgent;
  late final dynamic navigatorAgent;
  late final dynamic orchestratorAgent;
  late dynamic _chat;

  @override
  void initState() {
    super.initState();

    ai = Genkit(
      plugins: [
        googleAI(
          apiKey: dotenv.env['GEMINI_API_KEY'] ??
              const String.fromEnvironment('GEMINI_API_KEY'),
        ),
        AgentsPlugin(),
      ],
      model: googleAI.gemini('gemini-2.5-flash-lite'),
    );

    // 1. Sub-agent: Stylist
    stylistAgent = ai.defineAgent(
      name: 'stylist',
      description: 'Specialist for application color palette, mood, and visual styling.',
      system: 'You are a master UI color designer. When asked, recommend an exact hex color and describe the mood.',
    );

    // 2. Sub-agent: Navigator
    navigatorAgent = ai.defineAgent(
      name: 'navigator',
      description: 'Specialist for app routing and screen management (home, settings, analytics).',
      system: 'You are an app navigation expert. Decide which screen best suits the user intent.',
    );

    // 3. Orchestrator Agent delegating via agents() middleware
    orchestratorAgent = ai.defineAgent(
      name: 'orchestrator',
      system:
          'You are the chief app orchestrator. '
          'Delegate styling questions to stylist and navigation questions to navigator. '
          'Synthesize their answers clearly for the user.',
      use: [
        agents(agents: ['stylist', 'navigator']),
      ],
      store: InMemorySessionStore(),
    );

    _chat = orchestratorAgent.chat();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    setState(() {
      _isLoading = true;
      _conversationLog.add('👤 User: $text');
    });

    try {
      final res = await _chat.send(text: text);
      final snapshotId = res.snapshotId ?? 'snap-${DateTime.now().millisecondsSinceEpoch}';

      setState(() {
        _conversationLog.add('🤖 Orchestrator: ${res.text}');
        _snapshotHistory.add(snapshotId);
      });
    } catch (e) {
      setState(() {
        _conversationLog.add('❌ Error: $e');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Rewind conversation to an earlier snapshot
  Future<void> _restoreSnapshot(String snapshotId) async {
    setState(() {
      _isLoading = true;
      _conversationLog.add('⏳ [Session] Rewinding conversation to snapshot: $snapshotId...');
    });

    try {
      _chat = await orchestratorAgent.loadChat(snapshotId: snapshotId);
      setState(() {
        _conversationLog.add('✓ Successfully restored session state from snapshot: $snapshotId');
      });
    } catch (e) {
      setState(() {
        _conversationLog.add('❌ Failed to restore snapshot: $e');
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
      appBar: AppBar(title: const Text('10. Multi-Agent Delegation & Sessions')),
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        itemCount: _conversationLog.length,
                        itemBuilder: (context, index) {
                          final log = _conversationLog[index];
                          final isUser = log.startsWith('👤');
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Text(
                              log,
                              style: TextStyle(
                                fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
                                color: isUser ? Colors.deepPurple : Colors.black87,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(
                            hintText: 'Ask: "Give me a cyberpunk color" or "Where should I go for profile settings?"',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _isLoading ? null : _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _sendMessage,
                        child: const Text('Send'),
                      ),
                    ],
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
                    'SESSION SNAPSHOTS',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Immutable snapshots allow rewinding or branching conversation state:',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  if (_isLoading)
                    const LinearProgressIndicator(color: Colors.amberAccent),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _snapshotHistory.length,
                      itemBuilder: (context, index) {
                        final snapId = _snapshotHistory[index];
                        return Card(
                          color: Colors.grey.shade900,
                          child: ListTile(
                            title: Text(
                              'Turn ${index + 1}',
                              style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              snapId,
                              style: const TextStyle(color: Colors.white60, fontSize: 10, fontFamily: 'monospace'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: TextButton(
                              onPressed: _isLoading ? null : () => _restoreSnapshot(snapId),
                              child: const Text('Rewind', style: TextStyle(color: Colors.cyanAccent)),
                            ),
                          ),
                        );
                      },
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
