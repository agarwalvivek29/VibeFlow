# VibeFlow

**Enterprise Voice-to-Text for Engineers** — Where Engineers Can Truly Vibe.

VibeFlow is an enterprise-grade voice dictation platform built for engineering teams. Press and hold a key, speak your thoughts, and get clean, formatted text pasted directly into any application.

> **Note:** VibeFlow is the enterprise offering built on top of [WhisprOSS](https://github.com/agarwalvivek29/WhisprOSS), the open-source foundation.

## Enterprise Features

- **Authentication & SSO** — Enterprise identity integration (Google Workspace, Microsoft Entra ID)
- **Managed AI Backend** — No API keys to configure, powered by VibeFlow's managed infrastructure
- **Snippets** — Define keyword triggers that expand into full text templates
- **Custom Dictionary** — Add technical terms, names, and jargon for accurate transcription
- **Usage Statistics** — Track words per minute, time saved, and productivity metrics
- **Long Transcription Mode** — Toggle mode for extended dictation sessions (no key holding required)

## Core Features

- **Universal Dictation** — Works across any macOS application (Slack, VS Code, Notion, browsers, etc.)
- **On-Device Transcription** — Uses Apple's Speech Recognition for fast, private transcription
- **AI-Powered Cleanup** — LLM processing removes filler words and adds proper formatting
- **Dynamic Island-Style HUD** — Minimal notch UI that expands during recording with live waveform
- **Full-Screen Support** — Overlay works even over full-screen applications
- **Multi-Monitor Support** — HUD follows your active screen
- **Customizable Writing Style** — Choose tone (casual, professional, creative, technical)
- **Transcription History** — Browse, search, and revisit past transcriptions

## How It Works

### Standard Mode (Hold)
1. **Press and hold `Fn` key** to start recording
2. **Speak naturally** — don't worry about "um"s or pauses
3. **Release the key** — text is transcribed, cleaned up, and pasted

### Long Transcription Mode (Toggle)
1. **Press `Fn + Space`** to start recording
2. **Speak for as long as you need**
3. **Press `Fn` or `Space`** again to stop and paste

## Requirements

- macOS 14.0+
- Microphone access
- Accessibility permission (for global hotkey)
- Speech Recognition permission
- VibeFlow account (enterprise license)

## Architecture

```
VibeFlow/
├── App/
│   ├── VibeFlowApp.swift              # App entry point
│   └── RootView.swift                  # Navigation coordinator
│
├── Models/
│   ├── AppSettings.swift               # User preferences
│   ├── TranscriptionEntry.swift        # History persistence
│   ├── Snippet.swift                   # Text expansion templates
│   ├── DictionaryEntry.swift           # Custom vocabulary
│   └── UsageStats.swift                # Productivity metrics
│
├── Services/
│   ├── ConversationController.swift    # Hotkey detection & workflow
│   ├── SpeechManager.swift             # Audio recording & transcription
│   ├── VibeFlowAPIClient.swift         # Managed backend integration
│   ├── AuthManager.swift               # Authentication & SSO
│   ├── SnippetManager.swift            # Text expansion logic
│   ├── DictionaryManager.swift         # Custom vocabulary handling
│   └── StatsTracker.swift              # Usage analytics
│
├── Views/
│   ├── Main/                           # Core navigation
│   ├── Settings/                       # Configuration UI
│   ├── HUD/                            # Recording overlay
│   ├── Snippets/                       # Snippet management
│   ├── Dictionary/                     # Vocabulary management
│   ├── Stats/                          # Usage dashboard
│   └── Onboarding/                     # First-run setup
│
└── Assets/
    └── Assets.xcassets/                # App icon and colors
```

## Backend

VibeFlow uses a managed Python backend. See [WhisprFlow-backend](../WhisprFlow-backend/) for the API specification.

## Technologies

- **SwiftUI** — Declarative UI framework
- **SwiftData** — On-device persistence
- **AVFoundation** — Audio input via AVAudioEngine
- **Speech** — On-device transcription via SFSpeechRecognizer
- **AppKit** — NSPanel for HUD, NSEvent for hotkey detection
- **CoreAudio** — Audio device selection

## License

Enterprise proprietary license. Contact sales@vibeflow.ai for licensing information.

---

**VibeFlow** — Where Engineers Can Truly Vibe.
