# 🎙️ VibeFlow

**⚡ 10x your input speed. Seriously.**

Developers who use VibeFlow type less and ship more. Hold a key, speak your thought, release — perfectly formatted text lands in your editor, terminal, Slack, wherever. No context switching. No breaking flow. Just pure velocity. 🚀

Built by engineers, for engineers. Fully offline. Zero subscriptions.

<p align="center">
  <a href="https://youtu.be/uCnKX6ldIxQ">
    <img src="https://img.shields.io/badge/▶%20WATCH%20DEMO-FF0000?style=for-the-badge&logo=youtube&logoColor=white" alt="Watch Demo" />
  </a>

  <br/><br/>

  <a href="https://youtu.be/uCnKX6ldIxQ">
    <img src="https://img.youtube.com/vi/uCnKX6ldIxQ/maxresdefault.jpg" width="700" alt="VibeFlow Demo — click to watch" />
  </a>
</p>

## 🤔 Why VibeFlow?

You think at ~400 words per minute. You type at ~80. That's an **80% bottleneck** between your brain and your code. VibeFlow obliterates it. 💥

- 💬 Dictate a Slack message in 3 seconds instead of 30
- 📝 Narrate a PR description while reviewing the diff
- 📖 Draft docs, comments, commit messages — all at the speed of thought
- ⌨️ Your hands stay on the keyboard, your cursor stays where it was

## ✨ Features

- 🌍 **Universal Dictation** — Works in any macOS app: VS Code, Slack, Notion, browsers, terminals, you name it
- 🎤 **Dual Speech Engines** — Apple Speech Recognition (instant) or WhisperKit (on-device Whisper, insanely accurate)
- 🧠 **Dual Text Cleanup** — Local SLM (Qwen 0.5B via MLX) or any remote LLM endpoint
- ✈️ **Fully Offline Mode** — WhisperKit + Local SLM = zero network dependency. Airplane mode? No problem
- 🧹 **Regex Filler Removal** — Strips "um", "uh", "like", "you know" before AI processing
- 📚 **Custom Dictionary** — Add your jargon (Kubernetes, Terraform, gRPC) for spot-on recognition
- 🏝️ **Dynamic Island HUD** — Slick notch overlay with live waveform while recording
- 🖥️ **Multi-Monitor Support** — HUD follows your active screen
- ✍️ **Writing Styles** — Casual, Professional, Creative, or Technical
- 🕐 **Transcription History** — Browse, search, and copy past transcriptions
- ⚙️ **Configurable Hotkeys** — Fn, Right Command, or any custom key combo

## 🔧 How It Works

```
Hold Fn → Speak → Release → Text appears in your active app
```

Pipeline under the hood:

```
Hotkey → [Speech Engine] → raw text → [Filler Remover] → [Text Processor] → paste
              ↑                                                  ↑
        Apple Speech                                       Local SLM (Qwen 0.5B)
           or                                                   or
        WhisperKit                                         Remote LLM
```

## 🏎️ Engine Options

| Stage | Option A | Option B |
|-------|----------|----------|
| **Speech-to-Text** | Apple Speech (built-in, fast) | WhisperKit (Whisper on Neural Engine) |
| **Text Cleanup** | Local SLM — Qwen 0.5B via MLX (~400MB, runs on GPU) | Remote LLM — any OpenAI-compatible endpoint |

Switch between engines in Settings. Models preload eagerly when selected.

## 📋 Requirements

- macOS 14.0+ (Sonoma)
- Apple Silicon (M1 or later) — required for MLX and WhisperKit
- 🎙️ Microphone permission
- ♿ Accessibility permission (for global hotkey)
- 🗣️ Speech Recognition permission (for Apple Speech engine)

## 🚀 Getting Started

### Build from Source

1. Clone the repo:
   ```bash
   git clone https://github.com/agarwalvivek29/VibeFlow.git
   cd VibeFlow
   ```

2. Open in Xcode:
   ```bash
   open VibeFlow.xcodeproj
   ```

3. Add SPM dependencies in Xcode (**File → Add Package Dependencies**):

   | Package | URL | Products |
   |---------|-----|----------|
   | WhisperKit | `https://github.com/argmaxinc/WhisperKit.git` | WhisperKit |
   | mlx-swift-lm | `https://github.com/ml-explore/mlx-swift-lm` | MLXLLM, MLXLMCommon |

   > **Note:** If you only want Apple Speech + Remote LLM, you can skip both dependencies — the app builds and runs without them.

4. Build and run: **Cmd+R** 🎉

5. Grant permissions when prompted:
   - **Accessibility** — System Settings → Privacy & Security → Accessibility → enable VibeFlow
   - **Microphone** — prompted automatically
   - **Speech Recognition** — prompted automatically

### 🎤 First Dictation

1. Press and hold **Fn** key
2. Speak naturally
3. Release — text appears in your active app

That's it. You're already faster. 🏃‍♂️💨

## 🏗️ Architecture

### Protocol-Based Engine System

Two protocols allow hot-swapping engines at runtime:

```swift
@MainActor protocol SpeechRecognitionService: AnyObject {
    var transcript: String { get }
    var level: Float { get }
    func startRecording(contextualTerms: [String]) throws
    func stopAndWaitForFinal() async -> String
    func stop()
}

protocol TextProcessingService {
    func process(text: String, systemPrompt: String) async throws -> String
}
```

### Engine Implementations

| Protocol | Class | Details |
|----------|-------|---------|
| SpeechRecognitionService | `AppleSpeechEngine` | Apple SFSpeechRecognizer, supports `contextualStrings` for custom dictionary |
| SpeechRecognitionService | `WhisperEngine` | WhisperKit (CoreML + Neural Engine), model auto-downloads |
| TextProcessingService | `LocalSLMProcessor` | Qwen 0.5B via MLX Swift, fully offline |
| TextProcessingService | `RemoteLLMProcessor` | Any OpenAI-compatible endpoint via LiteLLMClient |

### Core Services

- 🎛️ **ConversationController** — Orchestrates hotkey → record → process → paste. Loads dictionary terms from SwiftData, applies regex filler removal, then routes to the active text processor.
- 🧹 **FillerRemover** — Static regex patterns strip filler words before model processing.
- 📦 **ModelDownloadManager** — Downloads and caches Whisper/SLM models to `~/Library/Application Support/VibeFlow/Models/`.
- 🔐 **PermissionsHelper** — Checks/requests Accessibility, Microphone, Speech Recognition permissions.

### ⚙️ Settings (AppSettings.swift)

All persisted via UserDefaults. Key enums:
- `SpeechEngine`: `.apple`, `.whisper`
- `TextCleanupEngine`: `.localSLM`, `.remoteLLM`
- `WhisperModelSize`: `.tiny`, `.base`, `.small`
- `WritingStyle`: `.casual`, `.professional`, `.creative`, `.technical`
- `Formality`: `.informal`, `.neutral`, `.formal`

### 💾 Data Models (SwiftData)

- **TranscriptionEntry** — raw transcript, processed text, timestamp, word count, model used
- **DictionaryEntry** — term, category, isEnabled

### 🧩 Key Design Decisions

- **Protocol-based engines** — `SpeechRecognitionService` and `TextProcessingService` allow hot-swapping at runtime
- **No backend required** — Pure client app. Remote LLM is optional, not mandatory
- **Eager model preloading** — Models load when selected in settings, not on first use
- **Regex before SLM** — Filler words stripped by regex before the language model, reducing tokens and improving output
- **Dictionary via contextualStrings** — Custom terms fed to Apple Speech's `contextualStrings` API for better recognition

### 📁 File Structure

```
VibeFlow/
├── App/
│   ├── VibeFlowApp.swift              # Entry point, engine construction, preloading
│   └── RootView.swift
├── Models/
│   ├── AppSettings.swift              # Settings, enums, system prompt
│   ├── DictionaryEntry.swift          # Custom vocabulary (SwiftData)
│   ├── TranscriptionEntry.swift       # History (SwiftData)
│   ├── KeyBinding.swift               # Hotkey config
│   └── NavigationItem.swift           # Sidebar nav
├── Services/
│   ├── Protocols/
│   │   ├── SpeechRecognitionService.swift
│   │   └── TextProcessingService.swift
│   ├── AppleSpeechEngine.swift        # Apple Speech
│   ├── WhisperEngine.swift            # WhisperKit
│   ├── LocalSLMProcessor.swift        # MLX Qwen 0.5B
│   ├── RemoteLLMProcessor.swift       # LiteLLM wrapper
│   ├── FillerRemover.swift            # Regex filler removal
│   ├── LiteLLMClient.swift            # HTTP streaming client
│   ├── ConversationController.swift   # Main orchestrator
│   ├── ModelDownloadManager.swift     # Model download/cache
│   └── PermissionsHelper.swift        # macOS permissions
├── Views/
│   ├── Main/                          # Dashboard, History, Sidebar
│   ├── Settings/                      # Engine pickers, hotkeys, style
│   ├── Dictionary/                    # Custom vocab CRUD
│   ├── HUD/                           # Recording overlay
│   └── Components/                    # Shared UI
└── Assets.xcassets/
```

## 📊 Resource Usage

| Component | Disk | RAM |
|-----------|------|-----|
| App binary | ~20 MB | ~50 MB |
| WhisperKit (base model) | ~80 MB | ~100 MB |
| Qwen 0.5B (4-bit) | ~350 MB | ~500 MB |
| **Total (fully offline)** | **~450 MB** | **~650 MB** |

Runs comfortably on a base MacBook Air M1 with 8GB RAM. 💪

## 🛠️ Technologies

- **SwiftUI** + **SwiftData** — UI and persistence
- **AVFoundation** — Audio capture via AVAudioEngine
- **Speech.framework** — Apple on-device speech recognition
- **WhisperKit** — On-device Whisper via CoreML + Neural Engine
- **MLX Swift** — On-device LLM inference via Apple's ML framework
- **AppKit** — NSPanel for HUD overlay, NSEvent for global hotkey monitoring
- **CoreAudio** — Audio device selection and sample rate detection

## 🤝 Contributing

PRs welcome! The codebase is designed for extensibility:

- 🎤 **Add a new speech engine** — Conform to `SpeechRecognitionService` protocol
- 🧠 **Add a new text processor** — Conform to `TextProcessingService` protocol
- 🧹 **Improve filler removal** — Edit regex patterns in `FillerRemover.swift`
- 💬 **Better system prompt** — Edit `buildSystemPrompt()` in `AppSettings.swift`

### Build Requirements

- Xcode 15.0+
- Swift 5.9+
- macOS 14.0+ SDK

### Commit Convention

```
type: description
```
Types: `feat`, `fix`, `refactor`, `docs`, `chore`

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.

---

**🎙️ VibeFlow** — Stop typing. Start shipping. 🚀
