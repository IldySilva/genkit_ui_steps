# Flutter Goes AI: AI as a UI Remote Control
## Comprehensive Repository Overview, Genkit Deep-Dive & Presentation Master Guide

> **Purpose of this Document:** This document provides a complete, structured reference of the codebase in this repository and the overarching **Genkit Dart ecosystem**. It is designed for slide generators, AI assistants, and technical speakers preparing for the talk **"Flutter Goes AI: AI as a UI Remote Control"**.
> 
> It covers:
> 1. Core architectural concepts of **Genkit for Dart** (`https://genkit.dev/docs/dart`).
> 2. The **Beta/Experimental Agents framework** (`https://genkit.dev/docs/dart/agents/overview/`).
> 3. On-device / Offline execution using the modern community package **`genkit_flutter_edge_ai`** (`https://pub.dev/packages/genkit_flutter_edge_ai`).
> 4. Detailed analysis of each step implemented in this repository (`step1` to `step7`).
> 5. Speaker notes, live demo workflows, and Q&A survival tips.

---

## 1. Executive Summary & Core Philosophy

### The Central Thesis
* **Not Another Chatbot:** The objective is *not* to build another text chat bubble inside a mobile app. Chatbots keep the user trapped in a conversation window while the application remains static.
* **AI as a UI Remote Control:** We demonstrate how an AI model can serve as an intelligent, conversational interface to **control existing Flutter features and state**.
* **Clear Ownership Boundary:**
  > **"The AI does NOT generate Flutter code. The AI does NOT manipulate the widget tree. The AI selects capabilities (tools) that the Flutter developer explicitly exposes."**
* **The Inversion of Control:**
  > **"Flutter owns the widget tree, state management, and business logic. The AI is simply an interface that translates human natural-language intent into strongly typed tool executions."**

---

## 2. Core Concepts of Genkit Dart (`genkit.dev/docs/dart`)

Genkit is Google's open-source framework designed to help developers build, deploy, and monitor production AI applications with end-to-end type safety.

```text
┌───────────────────────────────────────────────────────────────────────────────┐
│                                 GENKIT CORE                                   │
├─────────────┬─────────────┬─────────────┬─────────────┬───────────────────────┤
│   MODELS    │   PROMPTS   │    TOOLS    │    FLOWS    │     OBSERVABILITY     │
│  Generate   │  Dotprompt  │  Function   │   Type-safe │   OpenTelemetry /     │
│  Streaming  │  Templates  │   Calling   │   Workflows │    Developer UI       │
└──────┬──────┴──────┬──────┴──────┬──────┴──────┬──────┴───────────┬───────────┘
       │             │             │             │                  │
┌──────▼─────────────▼─────────────▼─────────────▼──────────────────▼───────────┐
│                                 PLUGINS                                       │
│  Google GenAI (Gemini) │ LlamaDart │ Flutter Edge AI │ Vertex AI │ Shelf / HTTP│
└───────────────────────────────────────────────────────────────────────────────┘
```

### 1. The Genkit Instance & Plugin Architecture
Genkit acts as a centralized registry. Rather than coupling your code directly to an SDK like Google Generative AI or OpenAI, you instantiate Genkit with plugins:
```dart
import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';

final ai = Genkit(
  plugins: [
    googleAI(apiKey: const String.fromEnvironment('GEMINI_API_KEY')),
  ],
  model: googleAI.gemini('gemini-3.1-flash-lite'), // Optional default model
);
```
* **Benefit:** You can swap models, change providers (e.g. Gemini Cloud vs. Gemma on-device), or attach telemetry without refactoring business logic.

### 2. Models & Generation (`generate` & `generateStream`)
* **`ai.generate(...)`**: Single-shot call returning a full `GenerateResponse`. Ideal for structured data generation or one-off tasks.
* **`ai.generateStream(...)`**: Returns an asynchronous stream of chunks (`GenerateResponseChunk`). Essential for responsive mobile UX to avoid blocking the user interface during token generation.
* **Multimodal support**: Genkit natively accepts images, audio, and documents via `Part.media(...)` or data URIs alongside text prompts.

### 3. Strongly Typed Schemas (`schemantic`)
Genkit Dart relies on `schemantic` to guarantee end-to-end type safety between the LLM and the Dart runtime:
```dart
import 'package:schemantic/schemantic.dart';

@Schema()
abstract class $ThemeInput {
  String get color;
}
```
* Code generator (`dart run build_runner build`) creates `ThemeInput.$schema` and deserializers.
* Prevents runtime parsing errors: the model is constrained by JSON schema to return the exact types Dart expects.

### 4. Tools (Function Calling)
Tools give models the capability to perform actions or query external systems:
```dart
final tool = ai.defineTool(
  name: 'changeTheme',
  description: 'Changes visual theme color when user asks to alter appearance.',
  inputSchema: ChangeThemeInput.$schema,
  fn: (input, context) async {
    // Executes actual Dart/Flutter code
    return 'Success';
  },
);
```
* **Allow-list Security:** The model has zero access to Dart reflection, disk, or network unless wrapped inside a defined tool.

### 5. Flows (`ai.defineFlow`)
A Flow is an observable, type-safe pipeline that encapsulates multi-step logic (e.g., retrieving user data -> prompting LLM -> calling tools -> formatting output):
```dart
final userProfileFlow = ai.defineFlow(
  name: 'userProfileFlow',
  inputSchema: UserIdInput.$schema,
  outputSchema: ProfileOutput.$schema,
  fn: (input, context) async {
    // Steps are tracked and traceable
    return ProfileOutput(...);
  },
);
```
* **Observability:** Every step inside a flow is tracked automatically with inputs, outputs, and latencies.
* **Deployability:** Flows can run on-device inside Flutter, or be served over HTTP via `genkit_shelf` on Cloud Run, Dart Frog, or Docker.

### 6. Observability & Developer UI (`genkit_otel`)
* Run `genkit start` locally to open the **Genkit Developer UI**.
* Provides interactive prompt playgrounds, trace inspectors, latency breakdowns, and token counters.
* Production deployments export telemetry seamlessly via OpenTelemetry (Google Cloud Trace, Datadog, PostHog, etc.).

---

## 3. What is in Beta? Stateful Agents in Genkit Dart (`genkit.dev/docs/dart/agents/overview/`)

> [!NOTE]
> In Genkit Dart 1.0+, **Agents** represent the experimental/beta frontier (`package:genkit/experimental.dart`). Keep this high-level during the talk, but use it to demonstrate visionary leadership.

```text
Single-Shot Generation (ai.generate)          Stateful Agent (ai.defineAgent)
┌───────────────────────────────────┐        ┌───────────────────────────────────┐
│ Input Prompt                      │        │ User Message                      │
│       ↓                           │        │       ↓                           │
│ Model generates 1 response        │        │ Model evaluates history & tools   │
│       ↓                           │        │       ↓ (Autonomous Loop)         │
│ Executes 0 or 1 tool call         │        │ Model calls Tool 1 -> gets result │
│       ↓                           │        │ Model calls Tool 2 -> gets result │
│ Finished.                         │        │       ↓ (If sensitive)            │
│                                   │        │ Interrupt: Wait for Human confirm │
│                                   │        │       ↓                           │
│                                   │        │ Final Response + Session Saved    │
└───────────────────────────────────┘        └───────────────────────────────────┘
```

### Why Agents Matter (Agent vs. Simple Generation):
1. **Autonomous ReAct Loops (Reasoning + Acting):**
   * While `ai.generate` requires the caller to manage loops or single steps, `defineAgent` loops automatically: it evaluates the goal, executes Tool A, reads the result, realizes it also needs Tool B, executes Tool B, and synthesizes the answer.
2. **Session Persistence & State:**
   * Agents retain conversation history and arbitrary state schemas across multiple turns and app restarts using built-in session stores (memory, file, or cloud database like Firestore).
3. **Human-in-the-Loop & Tool Interrupts (`.interrupt(...)`):**
   * Critical for safety: If an agent decides to call a high-risk tool (e.g. `transferMoney` or `wipeData`), the tool triggers an `.interrupt()`. The execution halts, the agent prompts the user in the UI for confirmation, and upon approval, execution resumes seamlessly.
4. **Transport-Agnostic & Remote Agents:**
   * You can declare an agent on a Dart backend using Shelf/Dart Frog, and connect your Flutter app using `remoteAgent()` or the uniform `chat()` interface.
5. **Model Context Protocol (MCP) Integration:**
   * Using `genkit_mcp`, agents can discover and connect to external MCP tool servers dynamically at runtime.

#### Quick Code Peek (Agents Beta):
```dart
import 'package:genkit/genkit.dart';
import 'package:genkit/experimental.dart';

final conciergeAgent = ai.defineAgent(
  name: 'conciergeAgent',
  system: 'You are a proactive app assistant. Help users configure and navigate the app.',
  tools: [changeThemeTool, navigateTool, queryCatalogTool],
);
```

---

## 4. Offline & On-Device AI: The `genkit_flutter_edge_ai` Package

### How to Position It on Stage:
> *"What if you are in airplane mode, or working in healthcare/finance where no byte can leave the device?*
> *While `genkit_google_genai` powers our cloud calls, there is an incredible community package called **`genkit_flutter_edge_ai`**.*
> *It is not an official Google package, but it is built on top of the Flutter Edge AI ecosystem (formerly `flutter_gemma`) by active community contributors. It is well-maintained, robust, and shows the true strength of Genkit: **The tools and UI code stay identical; only the model provider changes.**"*

```text
                          FLUTTER APPLICATION
                      (setState / Navigator / UI)
                                   │
                           GENKIT ABSTRACTION
                                   │
              ┌────────────────────┴────────────────────┐
              ▼                                         ▼
      CLOUD PROVIDER                             EDGE PROVIDER
   genkit_google_genai                       genkit_flutter_edge_ai
  (gemini-3.1-flash-lite)                     (Gemma 2B / Qwen / Phi)
              │                                         │
       Google Servers                        On-Device (LiteRT-LM / GPU)
```

### What `genkit_flutter_edge_ai` Offers:
* **True On-Device Inference:** Uses **LiteRT-LM** (Google LiteRT) or **MediaPipe** under the hood to run local GGUF/LiteRT models directly on mobile GPUs/NPUs.
* **Full Tool / Function Calling Support:** Local models can trigger Genkit tools with parallel calls and strict `toolChoice` (`auto`, `required`, `none`).
* **Structured Output Support:** Guarantees typed JSON parsing directly on-device using Genkit schemas.
* **Context Trimming Middleware (`trimContext`):** Automatically truncates conversation history to fit mobile KV-cache constraints and prevent memory exhaustion.
* **Thinking Mode & Multimodal:** Supports modern reasoning models (DeepSeek-R1 distillations, Qwen, Gemma) and on-device vision input.

### Integration Example:
```dart
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_flutter_edge_ai/genkit_flutter_edge_ai.dart';

void setupEdgeGenkit() async {
  // 1. Initialize Flutter Edge AI Engine
  await FlutterEdgeAi.initialize(
    inferenceEngines: const [LiteRtLmEngine()],
  );

  // 2. Download or point to local model
  await FlutterEdgeAi.installModel(
    modelType: ModelType.gemma4,
    fileType: ModelFileType.litertlm,
  ).fromNetwork('https://huggingface.co/.../model.litertlm').install();

  // 3. Invoke via Genkit with the exact same tools!
  final ai = Genkit();
  final response = await ai.generate(
    model: flutterEdgeAi.model('gemma-4-e2b'),
    prompt: 'Make the app dark and navigate to settings.',
    toolNames: [changeThemeTool.name, navigateTool.name],
  );
}
```

---

## 5. Repository File Map & Implementation Details

```text
genkit/
├── pubspec.yaml                     # Dependencies (genkit, genkit_google_genai, genkit_llamadart, genkit_middleware, schemantic)
├── .env                             # Local environment variables (GEMINI_API_KEY) - Git ignored
├── .env.example                     # Example environment template for team/presentation
├── macos/Runner/
│   ├── DebugProfile.entitlements    # com.apple.security.network.client = true
│   └── Release.entitlements         # com.apple.security.network.client = true
├── lib/
│   ├── main.dart                    # Launches Step 7 by default (with dotenv initialization)
│   ├── main_step1.dart              # Direct runner for Step 1
│   ├── main_step2.dart              # Direct runner for Step 2
│   ├── main_step3.dart              # Direct runner for Step 3
│   ├── main_step4.dart              # Direct runner for Step 4
│   ├── main_step5.dart              # Direct runner for Step 5
│   ├── main_step6.dart              # Direct runner for Step 6
│   ├── main_step7.dart              # Direct runner for Step 7
│   ├── main_step8.dart              # Direct runner for Step 8
│   ├── main_step9.dart              # Direct runner for Step 9
│   ├── main_step10.dart             # Direct runner for Step 10
│   └── steps/
│       ├── step1_basic.dart         # Step 1: Basic text generation
│       ├── step2_streaming.dart     # Step 2: Streaming output
│       ├── step3_structured.dart    # Step 3: Typed structured JSON output
│       ├── step3_structured.g.dart  # Generated Schemantic code
│       ├── step4_tools.dart         # Step 4: Function calling with activity inspector
│       ├── step4_tools.g.dart       # Generated Schemantic code
│       ├── step5_local.dart         # Step 5: Local model integration (llama.cpp)
│       ├── step5_local.g.dart       # Generated Schemantic code
│       ├── step6_agent_interrupt.dart   # Step 6: Stateful Agent with Human-in-the-Loop Interrupts
│       ├── step6_agent_interrupt.g.dart # Generated Schemantic code
│       ├── step7_final.dart         # Step 7: Consolidated Final Demo
│       ├── step7_final.g.dart       # Generated Schemantic code
│       ├── step8_embeddings.dart    # Step 8: Vector Embeddings & Semantic Search
│       ├── step9_middlewares_cancellation.dart # Step 9: Custom Middleware & Stream Cancel
│       └── step10_multi_agent_sessions.dart    # Step 10: Multi-Agent & Snapshot Sessions
```

---

## 6. The 10 Progressive Steps (Slide-by-Slide Narrative)

```text
Step 1: Basic AI           -> AI as a remote string function (blocks UI)
       ↓
Step 2: Streaming          -> Asynchronous token streaming into widget tree
       ↓
Step 3: Structured Output  -> Strong typing with schemantic (ThemeCommand)
       ↓
Step 4: Function Calling   -> AI chooses capabilities (changeTheme, navigateTo) [THE WOW MOMENT]
       ↓
Step 5: Local AI           -> Same tools & UI, run on-device (llamadart / flutter_edge_ai)
       ↓
Step 6: Agents & Safety    -> Human-in-the-Loop Interrupts for sensitive actions
       ↓
Step 7: Final Demo         -> Consolidated Material 3 Remote Control UI with live inspector
       ↓
Step 8: Vector Embeddings  -> Semantic search & cosine similarity without hallucinations
       ↓
Step 9: Middlewares        -> Intercepting models, measuring latency, retries & live cancel
       ↓
Step 10: Multi-Agent & Sessions -> Orchestrator delegating to sub-agents & snapshot rewinds
```

---

### Step 1: Basic AI (Call & Response)
* **File:** `lib/steps/step1_basic.dart` (Runner: `lib/main_step1.dart`)
* **Goal:** Prove communication between Flutter and Gemini with minimal lines of code.
* **Model:** `gemini-3.1-flash-lite`
* **Code:**
  ```dart
  final ai = Genkit(
    plugins: [googleAI(apiKey: const String.fromEnvironment('GEMINI_API_KEY'))],
  );

  final response = await ai.generate(
    model: googleAI.gemini('gemini-3.1-flash-lite'),
    prompt: 'Explain Flutter in one sentence.',
  );
  print(response.text);
  ```
* **Speaker Script:**
  > *"Let's start with the simplest possible thing: Flutter asking an AI model a question. That's it — we have AI in Dart. But notice the flaw: we are treating AI like an old-fashioned synchronous string function. The UI freezes or spins while waiting."*

---

### Step 2: Streaming (Fluid UX)
* **File:** `lib/steps/step2_streaming.dart` (Runner: `lib/main_step2.dart`)
* **Goal:** Deliver instant visual feedback by streaming chunks directly to Flutter's `setState()`.
* **Code:**
  ```dart
  final stream = ai.generateStream(
    model: googleAI.gemini('gemini-3.1-flash-lite'),
    prompt: 'Explain why Flutter is good for building AI applications.',
  );

  await for (final chunk in stream) {
    setState(() {
      _answer += chunk.text;
    });
  }
  ```
* **Speaker Script:**
  > *"Now Flutter doesn't wait for the AI — it renders words as they are generated. But there is still a major problem: Flutter has no semantic understanding of this text. It's just prose on a screen. Flutter cannot drive logic with paragraphs."*

---

### Step 3: Structured Output (Machine-Readable Typing)
* **File:** `lib/steps/step3_structured.dart` (Runner: `lib/main_step3.dart`)
* **Goal:** Enforce contract typing using `schemantic`. The AI outputs a validated Dart object.
* **Code:**
  ```dart
  @Schema()
  abstract class $ThemeCommand {
    String get color;
    String get mood;
  }

  final response = await ai.generate(
    model: googleAI.gemini('gemini-3.1-flash-lite'),
    prompt: 'User wants: "Make it dark and gloomy". Return theme configuration.',
    outputSchema: ThemeCommand.$schema,
  );

  final ThemeCommand cmd = response.output;
  // Access typed fields: cmd.color, cmd.mood
  ```
* **Speaker Script:**
  > *"Now the AI outputs structured data our code understands. But notice who is in the driver's seat: the developer is still manually writing switch statements for every response. What if the AI could decide which action to take?"*

---

### Step 4: Function Calling — The "Wow Moment"
* **File:** `lib/steps/step4_tools.dart` (Runner: `lib/main_step4.dart`)
* **Goal:** Turn normal Flutter methods into Genkit Tools. The model selects and invokes them.
* **Tools Defined:**
  1. `changeTheme(color)` -> Parses hex string, updates seed color and recalculates luminance.
  2. `navigateTo(screen)` -> Uses `navigatorKey.currentState?.pushNamed('/settings')`.
* **Code:**
  ```dart
  final changeThemeTool = ai.defineTool(
    name: 'changeTheme',
    description: 'Changes visual theme color when user asks to alter appearance.',
    inputSchema: ChangeThemeInput.$schema,
    fn: (input, _) async {
      widget.onThemeChanged(input.color);
      return 'Theme changed to ${input.color}';
    },
  );

  await ai.generate(
    model: googleAI.gemini('gemini-3.1-flash-lite'),
    prompt: 'Make the app dark and gloomy and open settings.',
    toolNames: [changeThemeTool.name, navigateTool.name],
  );
  ```
* **The Live Interaction:**
  * Speaker types: `"Make the app dark and gloomy and open settings"`
  * The terminal inspects:
    ```text
    AI ACTIVITY
    🤔 Understanding request...
    🔧 changeTheme (color: #121212)
    🔧 navigateTo (screen: settings)
    ✓ Tool executed
    ```
  * The Flutter app switches to a dark theme and transitions to the settings screen simultaneously!
* **Speaker Script:**
  > *"I did not click a dark mode button. I did not write an if-statement for this sentence. The user expressed an intention, the model interpreted that intention, selected the tools, and those tools mutated our Flutter state."*

---

### Step 5: Local AI (Portability)
* **File:** `lib/steps/step5_local.dart` (Runner: `lib/main_step5.dart`)
* **Goal:** Demonstrate that Genkit abstracts the AI backend completely.
* **Code:**
  ```dart
  final plugin = llamaDart(
    models: const [
      LlamaModelDefinition(name: 'local-chat', modelPath: '/models/model.gguf')
    ],
  );
  final ai = Genkit(plugins: [plugin]);

  // Exact same generate call and tools!
  await ai.generate(
    model: llamaDart.model('local-chat'),
    prompt: prompt,
    toolNames: [changeThemeTool.name, navigateTool.name],
  );
  ```
* **Speaker Script:**
  > *"The intelligence can move from cloud to device. The tools stay. The Flutter app stays. Genkit abstracts the runtime."*

---

### Step 6: Stateful Agent with Human-in-the-Loop Interrupts (Experimental Beta)
* **File:** `lib/steps/step6_agent_interrupt.dart` (Runner: `lib/main_step6.dart` or branch `step/6-agents`)
* **Goal:** Demonstrate enterprise safety with **`ai.defineAgent`** and **Tool Interrupts** (`ToolResult.interrupt(...)`).
* **Concept:**
  When the user asks for a high-risk or destructive operation (e.g., *"Reset all application data and set theme to Red"*), the agent does NOT execute blindly. It yields an **Interrupt**. Flutter intercepts `res.interrupts`, displays a native security confirmation dialog, and upon approval resumes the turn via `chat.resume(...)`.
* **Code Implementation:**
  ```dart
  import 'package:genkit/experimental.dart';

  final resetSettingsTool = ai.defineTool(
    name: 'resetSettings',
    description: 'DANGEROUS ACTION: Resets all app settings. Requires human approval.',
    inputSchema: ResetSettingsInput.$schema,
    fn: (input, _) async => ToolResult.interrupt({
      'action': 'resetSettings',
      'reason': input.reason,
    }),
  );

  final assistantAgent = ai.defineAgent(
    name: 'assistantAgent',
    system: 'You are a Flutter controller agent with human-in-the-loop approval.',
    tools: [changeThemeTool, resetSettingsTool],
    store: InMemorySessionStore(),
  );

  // Execute in Flutter:
  final chat = assistantAgent.chat();
  final res = await chat.send(text: 'Reset all application data');
  if (res.interrupts.isNotEmpty) {
    // Show Flutter AlertDialog -> if approved:
    await chat.resume(
      respond: [res.interrupts.first.respond({'approved': true})],
    );
  }
  ```
* **Speaker Script:**
  > *"What happens when the AI wants to do something dangerous? It doesn't run arbitrary code. It triggers an Interrupt. The agent pauses, hands control back to Flutter, we ask the human for approval in a native dialog, and upon confirmation, the agent resumes execution seamlessly."*

---

### Step 7: Final Polished Demo
* **File:** `lib/steps/step7_final.dart` (Default: `lib/main.dart` or `lib/main_step7.dart` | Branch: `step/7-final`)
* **Goal:** A cohesive, production-grade UI showcasing natural language control, dynamic theme luminance recalculation, and a live AI Activity Terminal.
* **Code Implementation:**
  ```dart
  // Model prompt instructing tool usage
  await ai.generate(
    model: googleAI.gemini('gemini-3.1-flash-lite'),
    prompt: '''
  You are controlling a Flutter application.
  You have access to tools that can change the theme and navigate between screens.
  When the user asks to change the visual appearance, use the changeTheme tool.
  When the user asks to open another screen, use the navigateTo tool.

  User request:
  ${_controller.text}
  ''',
    toolNames: [changeThemeTool.name, navigateTool.name],
  );
  ```
* **UI Layout & Visual Experience:**
  * Centered Material 3 card (width: 600) with dynamic theme colors.
  * Fast action buttons (`[ RUN ]`) and prompt suggestions:
    * *"Make the app dark and gloomy and open settings"*
    * *"Make it feel like a cyberpunk application"*
  * Monospace dark terminal showing live execution checkmarks:
    ```text
    ✓ changeTheme(#151515)
    ✓ navigateTo(settings)
    ```
* **Speaker Script:**
  > *"This started as a plain Flutter app. Now we can control navigation, styles, and behaviors using natural human language. And we didn't replace Flutter with AI — we gave Flutter AI capabilities."*
* **Key Takeaway for Slides:**
  * "Flutter owns the UI remote control. AI provides the intent translation."

---

### Step 8: Vector Embeddings & Semantic Search
* **File:** `lib/steps/step8_embeddings.dart` (Runner: `lib/main_step8.dart` or branch `step/8-embeddings`)
* **Goal:** Demonstrate `ai.embed` with `googleAI.textEmbedding('text-embedding-004')` to achieve 0-hallucination semantic matching using cosine similarity in pure Dart.
* **Code Implementation:**
  ```dart
  // 1. Pre-index theme catalog into 768-dimension vectors
  final embeddings = await ai.embed(
    documents: _catalog.map((item) => DocumentData(content: [TextPart(text: '${item.title}: ${item.description}')])).toList(),
    embedder: googleAI.textEmbedding('text-embedding-004'),
  );

  // 2. Embed user query (e.g. "somewhere cold and rainy")
  final queryEmbed = await ai.embed(
    documents: [DocumentData(content: [TextPart(text: userQuery)])],
    embedder: googleAI.textEmbedding('text-embedding-004'),
  );

  // 3. Compute cosine similarity in Dart
  final similarity = cosineSimilarity(queryEmbed.first.embedding, item.embedding);
  ```
* **UI Layout & Visual Experience:**
  * Left: Search input field and list of indexed theme items with live green check indicators.
  * Right: Real-time progress bars showing similarity percentages (e.g., `Autumn Forest & Rain: 88.4%`, `Cyberpunk Neon: 42.1%`).
  * Automatically applies the highest-scoring theme without LLM generation latency or risk of made-up hex codes.
* **Speaker Script:**
  > *"Not every problem requires generating prose. Sometimes what you need is semantic search. With `ai.embed`, we generate mathematical vector embeddings and compute cosine similarity in pure Dart without hallucination risk."*
* **Key Takeaway for Slides:**
  * "Embeddings translate fuzzy human concepts into mathematical distances in milliseconds."

---

### Step 9: Custom Middlewares, Retries & Stream Cancellation
* **File:** `lib/steps/step9_middlewares_cancellation.dart` (Runner: `lib/main_step9.dart` or branch `step/9-middlewares`)
* **Goal:** Master generation lifecycles: cancelling ongoing streams in real time and intercepting requests with custom Genkit middlewares.
* **Code Implementation:**
  ```dart
  // 1. Custom timing middleware
  class LatencyLoggingMiddleware extends GenerateMiddleware {
    @override
    Future<ModelResponse> model(request, ctx, next) async {
      final sw = Stopwatch()..start();
      final res = await next(request, ctx);
      sw.stop();
      print('Model latency: ${sw.elapsedMilliseconds}ms');
      return res;
    }
  }

  // 2. Cancellation via StreamSubscription
  _subscription = ai.generateStream(
    prompt: prompt,
    use: [latencyMiddleware(), retry(maxRetries: 2)],
  ).listen((chunk) => setState(() => text += chunk.text));

  // User hits [Cancel Stream]:
  await _subscription?.cancel();
  ```
* **UI Layout & Visual Experience:**
  * Real-time generation area with an active **[Cancel Stream]** button.
  * Side terminal logging middleware lifecycle events:
    ```text
    ⏱️ [Middleware] Calling model with 1 message(s)...
    ⏱️ [Middleware] Model responded in 382ms
    🛑 [Cancellation] User canceled stream generation mid-way.
    ```
* **Speaker Script:**
  > *"In production, users don't wait forever. If a response takes too long, they hit Cancel. With Genkit Dart, you can abort streams on demand and intercept calls with reusable middlewares for logging, security guardrails, and automated retries."*
* **Key Takeaway for Slides:**
  * "Reliability = Interceptors (Middleware) + Fault Tolerance (Retry) + User Control (Cancellation)."

---

### Step 10: Multi-Agent Orchestration & Snapshot Persistence
* **File:** `lib/steps/step10_multi_agent_sessions.dart` (Runner: `lib/main_step10.dart` or branch `step/10-multi-agent`)
* **Goal:** Sub-agent delegation using `AgentsPlugin` (`package:genkit_middleware`) and session rewinding via immutable snapshots.
* **Code Implementation:**
  ```dart
  // 1. Specialized Sub-agents
  final stylist = ai.defineAgent(name: 'stylist', description: 'Color and style expert');
  final navigator = ai.defineAgent(name: 'navigator', description: 'Screen routing expert');

  // 2. Orchestrator with delegation middleware
  final orchestrator = ai.defineAgent(
    name: 'orchestrator',
    use: [agents(agents: ['stylist', 'navigator'])],
    store: InMemorySessionStore(),
  );

  // 3. Rewind to prior turn via snapshot ID:
  final restoredChat = await orchestrator.loadChat(snapshotId: priorSnapshotId);
  ```
* **UI Layout & Visual Experience:**
  * Multi-turn chat box displaying conversations with the Orchestrator.
  * Side panel showing the chain of **Session Snapshots** (`Turn 1`, `Turn 2`, `Turn 3`) with a **[Rewind]** button.
  * Clicking "Rewind" restores the entire agent state and conversation history to that exact moment in time.
* **Speaker Script:**
  > *"As applications grow, one prompt can't do everything. We divide responsibilities among specialized sub-agents and keep immutable session snapshots, allowing users to rewind conversation history at will."*
* **Key Takeaway for Slides:**
  * "Orchestrators coordinate specialists. Snapshots provide conversation time-travel."

---

## 7. How to Run Each Demo

### ⚡ Quick-Switch via Makefile (Fastest for Live Stage Presentation!)
A presentation `Makefile` is committed across every branch. You can seamlessly jump between steps with short, memorable commands:

```bash
make step1    # Switch to Step 1: Basic AI (Call & Response)
make step2    # Switch to Step 2: Streaming Tokens into UI
make step3    # Switch to Step 3: Structured Output (schemantic)
make step4    # Switch to Step 4: Function Calling [THE WOW MOMENT]
make step5    # Switch to Step 5: Local On-Device AI (llamadart)
make step6    # Switch to Step 6: Stateful Agent & Interrupts (Human-in-the-Loop)
make step7    # Switch to Step 7: Final Polished Remote Control
make step8    # Switch to Step 8: Vector Embeddings & Similarity Search
make step9    # Switch to Step 9: Custom Middlewares, Retries & Cancellation
make step10   # Switch to Step 10: Multi-Agent Delegation & Snapshot Rewind
make main     # Return to main branch

make run      # Run current branch (flutter run -d macos)
make status   # Check current branch and git status
make help     # Show the interactive presentation menu
```

---

You can also present using either of the traditional manual workflows:

### Workflow A: Git Branch Switching (Recommended for clean live demos)
Each step has its own dedicated Git branch where `lib/main.dart` points directly to that step's code. Keys are automatically read from the root `.env` via `flutter_dotenv`:

```bash
# Step 1: Basic AI
git checkout step/1-basic
flutter run -d macos

# Step 2: Streaming
git checkout step/2-streaming
flutter run -d macos

# Step 3: Structured Output
git checkout step/3-structured
flutter run -d macos

# Step 4: Function Calling (The Wow Moment)
git checkout step/4-tools
flutter run -d macos

# Step 5: Local AI (On-Device)
git checkout step/5-local
flutter run -d macos

# Step 6: Stateful Agent & Interrupts (Human-in-the-Loop)
git checkout step/6-agents
flutter run -d macos

# Step 7: Final Consolidated Demo
git checkout step/7-final
flutter run -d macos

# Step 8: Vector Embeddings & Semantic Search
git checkout step/8-embeddings
flutter run -d macos

# Step 9: Custom Middlewares & Stream Cancellation
git checkout step/9-middlewares
flutter run -d macos

# Step 10: Multi-Agent Delegation & Snapshot Rewind
git checkout step/10-multi-agent
flutter run -d macos
```

### Workflow B: Target File Runners (Fastest, stay on `main`)
Stay on the `main` branch and pass the specific `-t lib/main_stepX.dart` entry point (keys loaded automatically from `.env`):

```bash
# Run individual steps without branch switching:
flutter run -t lib/main_step1.dart -d macos
flutter run -t lib/main_step2.dart -d macos
flutter run -t lib/main_step3.dart -d macos
flutter run -t lib/main_step4.dart -d macos
flutter run -t lib/main_step5.dart -d macos
flutter run -t lib/main_step6.dart -d macos
flutter run -t lib/main_step7.dart -d macos
flutter run -t lib/main_step8.dart -d macos
flutter run -t lib/main_step9.dart -d macos
flutter run -t lib/main_step10.dart -d macos

# Default main (runs Step 7):
flutter run -d macos
```

---

## 8. High-Impact Speaker Advice & Q&A Cheat Sheet

### Presentation Timing Rule: "The 30-Second Rule"
* **Do NOT:** Spend 15 minutes explaining Genkit architecture slides at the start.
* **DO:** Say *"Genkit is the open-source AI layer for Dart"* in 30 seconds, then open the code. Let the audience experience the *"Wow Moment"* (Step 4) early, then explain how and why it works.

### Key Phrases to Repeat:
* *"The AI is not generating the UI. The AI is controlling the application through well-defined tools."*
* *"Tools are an allow-list: AI gets capabilities, not unrestricted access."*
* *"Flutter doesn't have to compete with AI. Flutter can be the interface through which AI becomes an application."*

### Q&A Survival Guide:
* **Q: "Isn't this just LangChain / Semantic Kernel for Dart?"**
  * *Answer:* "Genkit is built from the ground up by Google with first-class Dart and TypeScript support, strictly adhering to end-to-end type safety, native telemetry with OpenTelemetry, and tight integration with Flutter and Firebase."
* **Q: "What about latency with tool calling?"**
  * *Answer:* "With fast models like Gemini 3.1 Flash Lite or local edge models via `genkit_flutter_edge_ai`, tool selection takes 200–500ms. And with streaming chunks, user perceived latency is minimal."
* **Q: "Can the AI hallucinate destructive actions?"**
  * *Answer:* "No, because the AI cannot execute arbitrary code. It can only call the functions you supply with the arguments your schema permits. In high-risk scenarios, we use Genkit Agent interrupts for user confirmation."
