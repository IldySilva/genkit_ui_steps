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
├── pubspec.yaml                     # Dependencies (genkit, genkit_google_genai, genkit_llamadart, schemantic)
├── macos/Runner/
│   ├── DebugProfile.entitlements    # com.apple.security.network.client = true
│   └── Release.entitlements         # com.apple.security.network.client = true
├── lib/
│   ├── main.dart                    # Launches Step 7 by default
│   ├── main_step1.dart              # Direct runner for Step 1
│   ├── main_step2.dart              # Direct runner for Step 2
│   ├── main_step3.dart              # Direct runner for Step 3
│   ├── main_step4.dart              # Direct runner for Step 4
│   ├── main_step5.dart              # Direct runner for Step 5
│   ├── main_step7.dart              # Direct runner for Step 7
│   └── steps/
│       ├── step1_basic.dart         # Step 1: Basic text generation
│       ├── step2_streaming.dart     # Step 2: Streaming output
│       ├── step3_structured.dart    # Step 3: Typed structured JSON output
│       ├── step3_structured.g.dart  # Generated Schemantic code
│       ├── step4_tools.dart         # Step 4: Function calling with activity inspector
│       ├── step4_tools.g.dart       # Generated Schemantic code
│       ├── step5_local.dart         # Step 5: Local model integration (llama.cpp)
│       ├── step5_local.g.dart       # Generated Schemantic code
│       ├── step7_final.dart         # Step 7: Consolidated Final Demo
│       └── step7_final.g.dart       # Generated Schemantic code
```

---

## 6. The 7 Progressive Steps (Slide-by-Slide Narrative)

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
Step 6: Deploy Everywhere  -> Flows on mobile, web, and backend services
       ↓
Step 7: Final Demo         -> Consolidated Material 3 Remote Control UI with live inspector
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

### Step 6: Deploy Everywhere (Flows & Architecture)
* **Goal:** Explain how Genkit Flows decouple AI logic into reusable services.
* **Concept:**
  ```text
                   GENKIT FLOW (Service Layer)
                               │
            ┌──────────────────┼──────────────────┐
            ▼                  ▼                  ▼
       Mobile (Flutter)   Web (Flutter)      Cloud Server
       Local Execution    Local Execution    (Shelf / Dart Frog)
  ```
* **Speaker Script:**
  > *"You don't have to keep AI logic locked inside a single Flutter screen. Wrap it into a Genkit Flow. Run it directly in the app, or deploy it to a server and call it over streaming RPCs."*

---

### Step 7: Final Polished Demo
* **File:** `lib/steps/step7_final.dart` (Default: `lib/main.dart` or `lib/main_step7.dart`)
* **Goal:** Consolidated production-grade UI with Material 3 dynamic color scheme, clear prompt suggestions, and an AI Activity Inspector.
* **System Prompt:**
  ```text
  You are controlling a Flutter application.
  You have access to tools that can change the theme and navigate between screens.
  When the user asks to change the visual appearance, use the changeTheme tool.
  When the user asks to open another screen, use the navigateTo tool.
  ```

---

## 7. How to Run Each Demo

```bash
# Ensure dependencies & schema code generation are ready
flutter pub get
dart run build_runner build

# Run individual steps:
flutter run -t lib/main_step1.dart -d macos --dart-define=GEMINI_API_KEY=YOUR_KEY
flutter run -t lib/main_step2.dart -d macos --dart-define=GEMINI_API_KEY=YOUR_KEY
flutter run -t lib/main_step3.dart -d macos --dart-define=GEMINI_API_KEY=YOUR_KEY
flutter run -t lib/main_step4.dart -d macos --dart-define=GEMINI_API_KEY=YOUR_KEY
flutter run -t lib/main_step5.dart -d macos
flutter run -t lib/main_step7.dart -d macos --dart-define=GEMINI_API_KEY=YOUR_KEY

# Default main (Step 7):
flutter run -d macos --dart-define=GEMINI_API_KEY=YOUR_KEY
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
