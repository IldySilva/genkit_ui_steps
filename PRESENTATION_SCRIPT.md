# Master Presentation Script: Flutter Goes AI (AI as a UI Remote Control)

**Duration:** 35–40 Minutes  
**Speaker:** Technical Architect / Senior Flutter Engineer  
**Live Demo Mechanism:** Presentation `Makefile` (`make step1` ... `make step11`)  
**Core Framework:** Genkit for Dart (`https://genkit.dev/docs/dart`)

---

## Presentation Timing & Act Breakdown

| Act | Time | Slides | Topic & Live Demo |
|:---|:---:|:---:|:---|
| **Act 0: The Hook** | 00:00 – 04:00 (4m) | Slides 1–4 | The Fallacy of Chatbots & The UI Remote Control Thesis |
| **Act 1: Core Mechanics** | 04:00 – 09:00 (5m) | Slides 5–8 | Genkit Anatomy: Generate, Streaming & Structured Schemas (`step1`–`step3`) |
| **Act 2: The Aha! Moment** | 09:00 – 16:00 (7m) | Slides 9–12 | Function Calling Live & On-Device Edge AI (`step4`–`step5`) |
| **Act 3: Production Hardening** | 16:00 – 23:00 (7m) | Slides 13–16 | Embeddings (Zero Hallucination) & Middlewares/Cancel (`step6`–`step7`) |
| **Act 4: Autonomous Agents** | 23:00 – 31:00 (8m) | Slides 17–20 | Human-in-the-Loop Interrupts & Multi-Agent Snapshots (`step8`–`step9`) |
| **Act 5: The Grand Finale** | 31:00 – 35:00 (4m) | Slides 21–22 | Consolidated Production Remote Control Dashboard (`step10`) |
| **Act 6: One More Thing...** | 35:00 – 38:00 (3m) | Slides 23–24 | Beyond Remote Control: A2UI Generative UI (`step11`) |
| **Act 7: Conclusion & Q&A** | 38:00 – 40:00 (2m) | Slide 25 | Key Takeaways & Opening Floor for Questions |

---

## Detailed Slide-by-Slide Script

### [00:00 – 01:30] Slide 1: Title Slide
* **Visual:** Minimalist slide with title: **"Flutter Goes AI: AI as a UI Remote Control"**, speaker details, Genkit + Flutter logos.
* **Speaker Script (Verbatim):**
  > "Good morning, everyone.
  >
  > Over the past two years, almost every mobile application has been under immense pressure to add 'AI'. And how has the industry responded? 
  >
  > By sticking a floating chat bubble in the bottom right corner of the screen. 
  >
  > You tap it, a chat window slides up, covering your beautiful Flutter UI, and you talk to a bot in isolation. The application itself remains completely blind and deaf to what is happening inside that conversation.
  >
  > Today, I want to propose an entirely different paradigm. We are not going to build another chatbot. We are going to turn AI into an **intelligent Remote Control for your existing Flutter application**."

---

### [01:30 – 02:45] Slide 2: The Problem with Chatbot-in-a-Box
* **Visual:** Split screen. Left: Generic chat bubble covering a mobile app. Right: Frustrated user copy-pasting info back and forth.
* **Speaker Script (Verbatim):**
  > "Think about user interfaces for a moment. Graphical user interfaces won because they give users tactile affordances: buttons, sliders, routing, visual state. 
  >
  > When you force a user to interact purely through text, you introduce cognitive friction. But when you only give them buttons, they have to navigate ten menus just to find a setting.
  >
  > What if the user could say: *'Make this app look dark and open my privacy settings'*, and the app just **did it**?
  >
  > Not by generating arbitrary code at runtime. Not by hallucinating a new UI tree. But by taking the user's intent and translating it into strongly typed calls to the Flutter functions you already built and tested."

---

### [02:45 – 04:00] Slide 3: The Ownership Boundary
* **Visual:** Diagram showing a strict barrier: Left side (Flutter: Widget Tree, Business Logic, State). Right side (LLM: Intent Translation). Middle: Strongly Typed Tools.
* **Speaker Script (Verbatim):**
  > "Here is the golden rule of our entire talk today:
  >
  > **Flutter owns the UI. The developer owns the state. The AI only owns intent interpretation.**
  >
  > The AI is never given permission to execute arbitrary scripts. Instead, we provide the model with an **allow-list of tools**—strongly typed Dart functions. The AI decides *which* tool to invoke, and Flutter handles the execution.
  >
  > To do this cleanly, in pure Dart, without relying on external Python microservices or messy HTTP wrappers, Google built **Genkit for Dart**."

---

### [04:00 – 05:30] Slide 4: Introducing Genkit for Dart
* **Visual:** Genkit architectural stack showing Core, Plugins (Google GenAI, Vertex AI, Ollama, LlamaDart), Prompts, Tools, Flows, and Observability.
* **Speaker Script (Verbatim):**
  > "What is Genkit? Genkit is Google's open-source framework for building production AI applications. You might have heard of it in TypeScript or Go. Recently, Google released first-class support for **Dart**.
  >
  > Why does this matter for Flutter developers?
  > 1. It is end-to-end type safe.
  > 2. It is plugin-based—you can swap Gemini Flash for an offline local Llama model without changing your UI code.
  > 3. It compiles natively with Flutter without needing mirrors or reflection.
  >
  > Let's look at the code and see how we build this, step by step."

---

### [05:30 – 06:45] Slide 5: Step 1 — Basic Call & Response
* **Visual:** Code snippet of `ai.generate` alongside the terminal command `make step1`.
* **Action:** Run `make step1` in terminal, show the screen.
* **Speaker Script (Verbatim):**
  > "We start at the absolute ground floor. Step 1: Basic AI.
  >
  > Let's look at how simple Genkit makes this in Dart:
  >
  > We initialize a `Genkit` instance with the `googleAI` plugin. Then we call `ai.generate()`, specify our model—here `gemini-3.1-flash-lite`—and provide a prompt.
  >
  > But notice what happens when I click 'Send' in the app:
  > The UI freezes or displays a spinner for 1.5 seconds, and then the entire wall of text pops up all at once.
  >
  > In 2026, nobody accepts a 2-second spinner before seeing the first word. Users want immediate feedback. That brings us to Step 2."

---

### [06:45 – 08:00] Slide 6: Step 2 — Streaming Tokens into the Widget Tree
* **Visual:** Diagram of chunked tokens streaming into a Flutter `Text` widget via `StreamSubscription`.
* **Action:** Run `make step2` in terminal.
* **Speaker Script (Verbatim):**
  > "Step 2 is Streaming.
  >
  > Instead of `ai.generate()`, we switch to `ai.generateStream()`.
  >
  > This returns an asynchronous Dart Stream of `GenerateResponseChunk`. As each token leaves Gemini's data center, Flutter receives it and calls `setState` to append it to our rendered string.
  >
  > Time-to-first-token drops from 1500 milliseconds down to 250 milliseconds. The perceived latency is virtually zero.
  >
  > But raw text is only good for chat. If we want AI to control our app, we cannot parse English sentences with regex. We need structured, validated data."

---

### [08:00 – 09:15] Slide 7: Step 3 — Structured Output with Schemantic
* **Visual:** Code showing `@Schema() abstract class $ThemeCommand` and generated typed output.
* **Action:** Run `make step3` in terminal.
* **Speaker Script (Verbatim):**
  > "Step 3: Structured Output.
  >
  > How do you guarantee the model returns valid JSON conforming to your Dart models?
  >
  > In Genkit Dart, we use the `schemantic` package. Notice this code:
  > We declare an abstract class with `@Schema()`, specifying a `hexColor` string and an integer `brightness`. The build runner generates `$schema`.
  >
  > When we pass `outputSchema: ThemeCommand.$schema` to `ai.generate()`, Genkit enforces schema adherence directly in the model's constrained decoding layer.
  >
  > The response is not a string. It is a strongly typed Dart object: `response.output?.hexColor`. If the model tries to return invalid markdown, it fails schema validation before touching your widget state.
  >
  > Now, we have streaming and type safety. Let's create the **Aha! Moment**."

---

### [09:15 – 12:30] Slide 8 & 9: Step 4 — Function Calling: The UI Remote Control
* **Visual:** Slide titled **"THE WOW MOMENT: Function Calling as UI Remote Control"**. Diagram showing User Prompt -> Gemini -> Tool Call -> Flutter State Update.
* **Action:** Run `make step4` in terminal, launch macOS app: `make run`.
* **Speaker Script (Verbatim):**
  > "This is Step 4, and this is the core idea of this presentation.
  >
  > Look at the code on this slide. We define two tools using `ai.defineTool`:
  > 1. `changeThemeTool`: takes a color input, and in its execution callback, it calls Flutter's `widget.onThemeChanged(input.color)`.
  > 2. `navigateToTool`: takes a screen name ('settings' or 'home') and executes `navigatorKey.currentState?.pushNamed(...)`.
  >
  > Notice what we did here:
  > The AI model **does not know how Flutter works**. The AI model does not have a reference to the `BuildContext`. 
  >
  > All the AI knows is: *'I have a tool called changeTheme, and a tool called navigateTo.'*
  >
  > Watch the live screen now:
  > I type: *'Make this app dark and gloomy, and take me to settings.'*
  >
  > I hit Run.
  >
  > Look at the AI Activity Terminal on the right:
  > First, the AI inspects the request. It issues `✓ changeTheme(#1a1a2e)`. The background instantly turns dark navy blue.
  > Second, in the exact same turn, it issues `✓ navigateTo(settings)`. The navigator pushes the settings route!
  >
  > The user expressed a complex multi-intent human request, and the AI orchestrated two completely different parts of our Flutter app state seamlessly."

---

### [12:30 – 16:00] Slide 10 & 11: Step 5 — Local On-Device AI (Zero Cloud, Zero Cost)
* **Visual:** Architecture of on-device LLM inference using `genkit_llamadart` / `genkit_flutter_edge_ai`.
* **Action:** Run `make step5` in terminal.
* **Speaker Script (Verbatim):**
  > "Now, a senior engineer in the audience is probably thinking:
  > *'This is great, but every time the user wants to toggle dark mode, you are paying Google Cloud 0.0001 cents and making a round-trip to a data center?'*
  >
  > That is a fair critique. And that brings us to Step 5: **Local On-Device AI**.
  >
  > Because Genkit is plugin-based, we can swap the Gemini cloud plugin for `genkit_llamadart` or the community package `genkit_flutter_edge_ai`.
  >
  > What does this mean?
  > It means we bundle a 1.5-billion-parameter quantized GGUF model—like Qwen 2.5 or Gemma 2 2B—directly into the app bundle or download it to the device cache.
  >
  > Through Dart FFI, Genkit binds to `llama.cpp` compiled with Apple Metal or Vulkan GPU acceleration.
  >
  > The exact same `changeThemeTool` and `navigateToTool` code runs without changing a single line. But now:
  > - It works in airplane mode.
  > - Latency is 150 milliseconds.
  > - Cloud cost is zero.
  > - User privacy is 100% preserved because no text leaves the phone."

---

### [16:00 – 19:30] Slide 12 & 13: Step 6 — Vector Embeddings & Semantic Search
* **Visual:** 3D vector space visualization. Comparing cosine similarity against LLM prompt matching.
* **Action:** Run `make step6` in terminal.
* **Speaker Script (Verbatim):**
  > "Now let's talk about production realities.
  >
  > Sometimes, you don't need a 2-billion parameter model to generate text. You need **search**.
  >
  > Imagine an app with 50 predefined themes. If you ask an LLM to pick a theme, it might hallucinate a theme that doesn't exist, or make up an invalid hex code.
  >
  > In Step 6, we demonstrate **Vector Embeddings** using Genkit's `ai.embed` with `googleAI.textEmbedding('text-embedding-004')`.
  >
  > When the app initializes, we vectorize our theme descriptions into 768-dimensional numerical vectors.
  >
  > When the user types *'a cozy rainy afternoon in London'*, we embed that query in 40 milliseconds. Then, in pure Dart, we compute the **Cosine Similarity** between the query vector and our catalog.
  >
  > Look at the UI:
  > It matches *'Autumn Rain & Coffee'* with an 89.2% match, and automatically applies the theme!
  >
  > There is zero risk of hallucination. It is mathematically deterministic, blisteringly fast, and costs a fraction of a generative prompt."

---

### [19:30 – 23:00] Slide 14 & 15: Step 7 — Middlewares, Retries & Live Stream Cancellation
* **Visual:** Onion diagram of Middlewares intercepting requests. Live Cancel button terminating an active stream.
* **Action:** Run `make step7` in terminal.
* **Speaker Script (Verbatim):**
  > "In production, networks fail, models throttle, and users change their minds. Step 7 covers **Middlewares and Stream Cancellation**.
  >
  > In Genkit, you can write custom `GenerateMiddleware` classes. In our code, we implemented `LatencyLoggingMiddleware`:
  > It wraps `next(request, ctx)`, starts a `Stopwatch`, logs the request payloads, records the exact millisecond latency, and injects telemetry headers.
  >
  > We also chained Genkit's built-in `retry(maxRetries: 2)` middleware to handle transient network drops.
  >
  > And look at the UI in Step 7:
  > When I trigger a long generative stream, an active **[Cancel Stream]** button appears.
  >
  > If the user taps it, we call `await _subscription?.cancel()`. 
  >
  > Flutter cleanly closes the connection, the model stops streaming, and our terminal logs the abort event. You must never leave a dangling stream consuming battery and memory."

---

### [23:00 – 27:00] Slide 16 & 17: Step 8 — Stateful Agents & Human-in-the-Loop Interrupts
* **Visual:** Flowchart of Human-in-the-Loop Interrupt. Tool execution paused -> Flutter AlertDialog -> User confirms -> Agent resumed.
* **Action:** Run `make step8` in terminal.
* **Speaker Script (Verbatim):**
  > "So far, our tools have performed safe operations: changing colors and switching tabs.
  >
  > But what happens in a banking app? What happens if the AI has a tool called `deleteAccount` or `transferMoney`?
  >
  > You can never allow an AI to execute a destructive action without explicit human confirmation.
  >
  > In Step 8, we introduce **Genkit Agents** and **Tool Interrupts** (`ToolResult.interrupt`).
  >
  > Look at what happens in the demo:
  > I ask: *'Reset all my settings to factory defaults and wipe application cache.'*
  >
  > The model evaluates the prompt and invokes `resetSettingsTool`. 
  >
  > But instead of executing, the tool returns `ToolResult.interrupt({ action: 'resetSettings' })`.
  >
  > The Genkit agent execution loop **pauses immediately**. Flutter detects `res.interrupts`, and pops up a native Material 3 `AlertDialog`:
  > *'The AI wants to reset all settings. Do you approve?'*
  >
  > If I click 'Cancel', the agent turn aborts. 
  > If I click 'Approve', Flutter calls `chat.resume()`, the action completes, and the user remains safely in control at all times."

---

### [27:00 – 31:00] Slide 18 & 19: Step 9 — Multi-Agent Delegation & Snapshot Rewind
* **Visual:** Orchestrator agent diagram delegating to Stylist and Navigator sub-agents. Timeline slider showing Session Snapshots with a Rewind button.
* **Action:** Run `make step9` in terminal.
* **Speaker Script (Verbatim):**
  > "As your application scales, a single agent prompt cannot hold all rules, tools, and business context.
  >
  > In Step 9, we introduce **Multi-Agent Orchestration** using `package:genkit_middleware/agents.dart`.
  >
  > We define specialized sub-agents:
  > - A `StylistAgent` dedicated solely to visual design and color harmonies.
  > - A `NavigatorAgent` dedicated solely to route authentication and screen permissions.
  >
  > Then, we define an `OrchestratorAgent`. When the user makes a request, the Orchestrator routes tasks to the specialist sub-agents.
  >
  > But here is the most powerful feature in Step 9: **Session Snapshots**.
  >
  > Look at the side panel. Every turn generates an immutable Snapshot ID stored in `InMemorySessionStore`.
  >
  > If the user interacts for 5 turns, and says: *'Actually, go back to how the app was 3 steps ago'*, we simply call `orchestrator.loadChat(snapshotId: priorSnapshotId)`.
  >
  > It is full conversational time travel with zero state corruption."

---

### [31:00 – 35:00] Slide 20 & 21: Step 10 — Master Production Remote Control (The Climax)
* **Visual:** Full polished Material 3 UI with dynamic luminance, active activity log, presets, navigation drawer, and route observer.
* **Action:** Run `make step10` in terminal, show the polished app.
* **Speaker Script (Verbatim):**
  > "Now, we bring everything we have learned into Step 10: **The Master UI Remote Control Showcase**.
  >
  > This is no longer a step-by-step tutorial snippet. This is a polished, production-grade Flutter application.
  >
  > Look at the details:
  > - It calculates background luminance in real time: if the AI selects a bright yellow theme, Flutter switches text and icons to dark. If it selects dark purple, it switches to light.
  > - It uses a global `RouteObserver` and `GlobalKey<NavigatorState>` to let the AI steer nested navigation safely.
  > - It features an interactive Activity Terminal that formats tool invocations cleanly with timing and parameters.
  >
  > Let's test it live:
  > I click the preset: *'Make the app dark and gloomy and open settings.'*
  >
  > Look at the smooth transition:
  > The theme morphs, the settings route opens, and the activity log provides immediate proof of execution.
  >
  > This proves our core thesis:
  > **You do not need to replace Flutter with AI. You give Flutter an AI Remote Control.**"

---

### [35:00 – 38:00] Slide 22 & 23: Step 11 — One More Thing... A2UI Generative UI
* **Visual:** Slide titled **"Beyond Remote Control: What is A2UI?"**. Diagram comparing Function Calling (static widgets) vs A2UI Dynamic Surfaces (`application/a2ui+json` -> `genui` Native Widgets).
* **Action:** Run `make step11` in terminal.
* **Speaker Script (Verbatim):**
  > "Before I wrap up, I have 'One More Thing' to share.
  >
  > Everything we have seen so far relies on pre-compiled Flutter screens. The AI can only click buttons and navigate to screens that *already exist* in your code.
  >
  > But what if the user needs a screen that you **never anticipated**?
  >
  > What if the user says: *'Create a customer satisfaction survey with three multiple choice questions and a submit button'*, or *'Generate a boarding pass for my flight tomorrow'*?
  >
  > Enter **A2UI: Agent to User Interface**.
  >
  > In Step 11, we integrate Google's official `genkit_a2ui` middleware and the `genui` package.
  >
  > Here is how it works:
  > The AI streams structured JSON envelopes adhering to the A2UI specification (`application/a2ui+json`).
  > Flutter's `SurfaceController` listens to these envelopes, and dynamically paints native Flutter widgets from a pre-registered catalog into a `Surface` widget.
  >
  > Watch the screen now:
  > I type: *'Generate a checkout summary card with a Pay button.'*
  >
  > Look at that! 
  > The AI did not generate Dart source code that needs compilation. It streamed semantic JSON components, and Flutter rendered native Material 3 Cards, Buttons, and Text on the fly!
  >
  > This is the future: Remote Control for your existing screens, and A2UI for screens born at runtime."

---

### [38:00 – 40:00] Slide 24 & 25: Conclusion & Q&A
* **Visual:** Summary slide with 3 golden rules, links to repository, Genkit docs (`genkit.dev/docs/dart`), and "Questions & Answers".
* **Speaker Script (Verbatim):**
  > "To conclude, remember these three principles when building AI into Flutter:
  >
  > 1. **Ditch the Chat Bubble:** Give AI access to your app's existing capabilities via Tools.
  > 2. **Type Safety is Non-Negotiable:** Use Genkit and `schemantic` to guarantee structured data contracts.
  > 3. **Keep Humans in the Loop:** Use Agent Interrupts for sensitive actions, and explore A2UI when dynamic surfaces are required.
  >
  > The entire codebase, with all 11 branches and the live demo Makefile, is open-source and available in this repository.
  >
  > Thank you so much for your time, and I am excited to open the floor to your questions!"
