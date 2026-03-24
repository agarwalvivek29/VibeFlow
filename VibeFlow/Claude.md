# VibeFlow — Developer Guide

## Overview

VibeFlow is an open-source macOS voice dictation app. Hold a hotkey, speak, release — formatted text pastes into the active app. Fully offline capable.

**Pipeline:** Hotkey → Speech Engine → Filler Removal → Text Processor → Paste

## Architecture

### Protocol-Based Engine System

Two protocols allow hot-swapping engines at runtime:

```swift
// Speech-to-text
@MainActor protocol SpeechRecognitionService: AnyObject {
    var transcript: String { get }
    var level: Float { get }
    func startRecording(contextualTerms: [String]) throws
    func stopAndWaitForFinal() async -> String
    func stop()
}

// Text cleanup
protocol TextProcessingService {
    func process(text: String, systemPrompt: String) async throws -> String
}
```

### Engine Implementations

| Protocol | Implementation | Details |
|----------|---------------|---------|
| SpeechRecognitionService | `AppleSpeechEngine` | Apple SFSpeechRecognizer, supports `contextualStrings` for dictionary |
| SpeechRecognitionService | `WhisperEngine` | WhisperKit (CoreML + Neural Engine), model auto-downloads |
| TextProcessingService | `LocalSLMProcessor` | Qwen 0.5B via MLX Swift, fully offline |
| TextProcessingService | `RemoteLLMProcessor` | Any OpenAI-compatible endpoint via LiteLLMClient |

### Core Services

- **ConversationController** — Orchestrates hotkey → record → process → paste. Loads dictionary terms from SwiftData, applies regex filler removal, then routes to text processor.
- **FillerRemover** — Static regex patterns strip "um", "uh", "like", "you know" etc. before model processing.
- **ModelDownloadManager** — Downloads and caches Whisper/SLM models to `~/Library/Application Support/VibeFlow/Models/`.
- **PermissionsHelper** — Checks/requests Accessibility, Microphone, Speech Recognition permissions.

### App Initialization (VibeFlowApp.swift)

Engines are constructed based on `AppSettings` at launch. `onChange` observers on settings trigger `rebuildEngines()` for runtime swapping. Models preload eagerly when selected.

### Data Models (SwiftData)

- **TranscriptionEntry** — History: raw transcript, processed text, timestamp, word count, model used
- **DictionaryEntry** — Custom vocabulary: term, category, isEnabled

### Settings (AppSettings.swift)

All persisted via UserDefaults with `didSet { save() }`. Key enums:
- `SpeechEngine`: `.apple`, `.whisper`
- `TextCleanupEngine`: `.localSLM`, `.remoteLLM`
- `WhisperModelSize`: `.tiny`, `.base`, `.small`
- `WritingStyle`: `.casual`, `.professional`, `.creative`, `.technical`
- `Formality`: `.informal`, `.neutral`, `.formal`

### HUD

`HUDWindowController` manages an always-visible NSPanel overlay. Idle state shows dots, recording state shows mic icon + animated waveform bars. Follows active screen on multi-monitor setups.

## File Structure

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

## Development

**Requirements:** macOS 14.0+, Xcode 15.0+, Swift 5.9+, Apple Silicon

**SPM Dependencies (optional):**
- WhisperKit: `https://github.com/argmaxinc/WhisperKit.git`
- mlx-swift-lm: `https://github.com/ml-explore/mlx-swift-lm` (products: MLXLLM, MLXLMCommon)

App builds and runs without these — Apple Speech + Remote LLM work with zero dependencies.

**Debug build location:**
```
~/Library/Developer/Xcode/DerivedData/VibeFlow-*/Build/Products/Debug/VibeFlow.app
```

**Testing hotkeys:** Use Right Command as fallback if Fn key behaves differently in your setup.

## Git Commit Guidelines

- Format: `type: description` (feat, fix, docs, refactor, chore)
- No co-author lines
- No AI mentions in commits
