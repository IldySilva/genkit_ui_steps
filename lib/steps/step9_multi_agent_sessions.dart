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
      debugShowCheckedModeBanner: false,
      title: 'Flutter Goes AI - Step 9 (Multi-Agent & Snapshots)',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
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
  final ScrollController _scrollController = ScrollController();
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
      model: googleAI.gemini(dotenv.env['GEMINI_MODEL'] ??
          const String.fromEnvironment('GEMINI_MODEL',
              defaultValue: 'gemini-2.5-flash-lite')),
    );

    // 1. Sub-agent: Stylist
    stylistAgent = ai.defineAgent(
      name: 'stylist',
      description:
          'Specialist for application color palette, mood, and visual styling.',
      system:
          'You are a master UI color designer. When asked, recommend an exact hex color and describe the mood.',
    );

    // 2. Sub-agent: Navigator
    navigatorAgent = ai.defineAgent(
      name: 'navigator',
      description:
          'Specialist for app routing and screen management (home, settings, analytics).',
      system:
          'You are an app navigation expert. Decide which screen best suits the user intent.',
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

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? customPrompt]) async {
    final text = customPrompt ?? _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    setState(() {
      _isLoading = true;
      _conversationLog.add('User: $text');
    });
    _scrollToBottom();

    try {
      final res = await _chat.send(text: text);
      final snapshotId =
          res.snapshotId ?? 'snap-${DateTime.now().millisecondsSinceEpoch}';

      setState(() {
        _conversationLog.add('Orchestrator: ${res.text}');
        _snapshotHistory.add(snapshotId);
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _conversationLog.add('[Error] $e');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Rewind conversation to an earlier snapshot
  Future<void> _restoreSnapshot(String snapshotId) async {
    setState(() {
      _isLoading = true;
      _conversationLog.add(
          '[Session] Rewinding conversation to snapshot: $snapshotId...');
    });
    _scrollToBottom();

    try {
      _chat = await orchestratorAgent.loadChat(snapshotId: snapshotId);
      setState(() {
        _conversationLog.add(
            '[Session] Successfully restored session state from snapshot: $snapshotId');
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _conversationLog.add('[Session] Failed to restore snapshot: $e');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildConversationArea() {
    return Container(
      constraints: const BoxConstraints(minHeight: 200, maxHeight: 380),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: _conversationLog.isEmpty
          ? Center(
              child: Text(
                'Conversation is empty. Choose a quick prompt below.',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              itemCount: _conversationLog.length,
              itemBuilder: (context, index) {
                final log = _conversationLog[index];
                final isUser = log.startsWith('User: ');
                final isSession = log.startsWith('[Session]');
                final isError = log.startsWith('[Error]');

                if (isSession) {
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.cyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      log,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.cyan,
                          fontFamily: 'monospace'),
                    ),
                  );
                }

                if (isError) {
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      log,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                          fontFamily: 'monospace'),
                    ),
                  );
                }

                final cleanContent = isUser
                    ? log.substring(6)
                    : (log.startsWith('Orchestrator: ')
                        ? log.substring(14)
                        : log);

                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.78,
                    ),
                    decoration: BoxDecoration(
                      color: isUser
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: isUser
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Text(
                          isUser ? 'You' : 'Orchestrator Agent',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isUser
                                ? Colors.white70
                                : Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          cleanContent,
                          style: TextStyle(
                            fontSize: 14,
                            color: isUser
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildSnapshotsSection() {
    return Container(
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
                'SESSION SNAPSHOTS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  fontSize: 12,
                ),
              ),
              if (_snapshotHistory.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amberAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_snapshotHistory.length} checkpoints',
                    style: const TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Rewind state to any point in the conversation history:',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 10),
          if (_snapshotHistory.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'No checkpoints yet. Ask questions to record snapshots automatically.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            )
          else
            Column(
              children: _snapshotHistory.asMap().entries.map((entry) {
                final index = entry.key;
                final snapId = entry.value;

                return Card(
                  color: Colors.grey.shade900,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.amberAccent.withValues(alpha: 0.2),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(
                      'Turn ${index + 1}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      snapId,
                      style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                          fontFamily: 'monospace'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: TextButton.icon(
                      icon: const Icon(Icons.history,
                          size: 14, color: Colors.cyanAccent),
                      label: const Text('Rewind',
                          style: TextStyle(
                              color: Colors.cyanAccent, fontSize: 12)),
                      onPressed:
                          _isLoading ? null : () => _restoreSnapshot(snapId),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('8. Multi-Agent & Sessions'),
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
                  Icon(Icons.groups_2_outlined, color: Colors.deepPurple),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Multi-Agent Delegation & Session Snapshots',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'The Orchestrator coordinates with Stylist and Navigator sub-agents. State is captured as immutable snapshots you can rewind.',
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
                    avatar: const Icon(Icons.palette, size: 16),
                    label: const Text('Stylist Question'),
                    onPressed: _isLoading
                        ? null
                        : () => _sendMessage(
                            'Give me an energetic cyberpunk color palette with hex codes.'),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.navigation, size: 16),
                    label: const Text('Navigator Question'),
                    onPressed: _isLoading
                        ? null
                        : () => _sendMessage(
                            'Where should I go to manage user profile and password settings?'),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('Combined Task'),
                    onPressed: _isLoading
                        ? null
                        : () => _sendMessage(
                            'Design a dark modern theme for settings and tell me where to navigate.'),
                  ),
                ],
              ),
            ],
          );

          final inputArea = Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'e.g. "Suggest a theme color" or "Where to go?"',
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
                  onSubmitted: (_) => _isLoading ? null : _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.send),
                onPressed: _isLoading ? null : () => _sendMessage(),
                label: Text(_isLoading ? 'Sending...' : 'Send'),
              ),
            ],
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
                  _buildConversationArea(),
                  const SizedBox(height: 12),
                  inputArea,
                  const SizedBox(height: 16),
                  _buildSnapshotsSection(),
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
                      _buildConversationArea(),
                      const SizedBox(height: 12),
                      inputArea,
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildSnapshotsSection(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
