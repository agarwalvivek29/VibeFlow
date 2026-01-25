# VibeFlow Voice-First Assistant for macOS

## Overview

VibeFlow is an enterprise voice-first dictation platform for macOS. Where Engineers Can Truly Vibe.

**Core Workflow:** Press-and-hold Fn key → record speech → release to stop → transcribe with Apple's on-device speech recognition → clean up with managed VibeFlow API → paste cleaned text into active application.

**Current Status: v0.1 - Enterprise MVP**

---

## Enterprise Product Goals

### Core Features (Inherited from WhisprOSS)
- **Press-and-hold Fn key** to start/stop recording
- **Long transcription mode** via Fn+Space toggle
- **Minimal HUD overlay** showing microphone icon and live audio waveform
- **On-device transcription** using `SFSpeechRecognizer` (fast, private)
- **LLM cleanup** via VibeFlow managed API
- **Auto-paste** cleaned text into active application
- **Multi-monitor support** with HUD appearing on the active screen

### Enterprise Features
- **Authentication** - OAuth/SSO with Google Workspace, Microsoft Entra ID
- **Snippets** - Keyword-triggered text expansion (/standup, /lgtm, etc.)
- **Custom Dictionary** - Technical terms, names, jargon for accurate transcription
- **Usage Statistics** - WPM, time saved, transcription count, streaks
- **Managed Backend** - No user API key configuration required

---

## Architecture

### Core Components

1. **SpeechManager.swift**
   - Manages `AVAudioEngine` for microphone input
   - Uses `SFSpeechRecognizer` for on-device transcription
   - Publishes real-time audio level for waveform animation
   - Explicitly sets system default audio input device

2. **VibeFlowAPIClient.swift** (replaces LiteLLMClient)
   - Authenticated API calls to VibeFlow backend
   - Streams chat completions with dictionary injection
   - Handles token refresh and session management

3. **ConversationController.swift**
   - Orchestrates the complete workflow
   - Monitors Fn key press/release via `flagsChanged` events
   - Handles toggle mode (Fn+Space) for long transcriptions
   - Coordinates speech → transcription → LLM → paste
   - Integrates with SnippetManager for text expansion

4. **AuthManager.swift** (NEW)
   - OAuth flow for Google/Microsoft
   - Token storage in Keychain
   - Session management and license validation

5. **SnippetManager.swift** (NEW)
   - CRUD operations for snippets
   - Keyword detection in transcribed text
   - Text expansion logic

6. **DictionaryManager.swift** (NEW)
   - Custom vocabulary management
   - Injects dictionary into LLM prompts

7. **StatsTracker.swift** (NEW)
   - Records transcription sessions
   - Calculates WPM, time saved, streaks
   - Syncs with backend for team leaderboards

8. **HUDWaveView.swift & HUDWindowController.swift**
   - Borderless, transparent overlay window
   - Shows mic icon + animated waveform based on audio level
   - Displays recording duration in toggle mode
   - Intelligent screen detection

9. **AppSettings.swift**
   - User preferences persisted to UserDefaults
   - Builds dynamic system prompts with dictionary injection
   - Recording mode preference (hold vs toggle)

10. **PermissionsHelper.swift**
    - Manages macOS permissions: Accessibility, Microphone, Speech Recognition
    - Provides UI helpers to request and check permissions

---

## Implementation Details

### Long Transcription Mode (Toggle)

```swift
// In ConversationController.swift
enum RecordingMode {
    case hold     // Standard press-and-hold
    case toggle   // Fn+Space to start, Fn or Space to stop
}

private var recordingMode: RecordingMode = .hold
private var toggleModeActive = false

let handleFlagsChanged: (NSEvent) -> Void = { [weak self] event in
    // Detect Fn+Space combination
    let fnPressed = event.modifierFlags.contains(.function)
    let spacePressed = // detect space key

    if fnPressed && spacePressed && !self.isRecording {
        // Start toggle mode
        self.recordingMode = .toggle
        self.toggleModeActive = true
        self.startRecording()
    } else if self.toggleModeActive && (fnPressed || spacePressed) && self.isRecording {
        // Stop toggle mode
        self.toggleModeActive = false
        Task { await self.stopAndProcess() }
    }
}
```

### Snippet Detection

```swift
// In SnippetManager.swift
func expandSnippets(in text: String) -> String {
    var result = text
    for snippet in snippets where snippet.isEnabled {
        if result.contains(snippet.keyword) {
            result = result.replacingOccurrences(of: snippet.keyword, with: snippet.content)
            recordUsage(snippet)
        }
    }
    return result
}

// Integration in ConversationController.stopAndProcess()
let processedText = await llm.streamChatCompletion(...)
let expandedText = snippetManager.expandSnippets(in: processedText)
pasteToFrontmostApp(expandedText)
```

### Dictionary Injection

```swift
// In VibeFlowAPIClient.swift
func buildSystemPrompt(with dictionary: [DictionaryEntry]) -> String {
    let words = dictionary.filter(\.isEnabled).map { entry in
        if let pronunciation = entry.pronunciation {
            return "\(entry.word) (pronounced: \(pronunciation))"
        }
        return entry.word
    }

    return """
    You are a dictation assistant. \(basePrompt)

    IMPORTANT: The following technical terms must be spelled exactly as shown:
    \(words.joined(separator: ", "))
    """
}
```

### Authentication Flow

```swift
// In AuthManager.swift
func authenticateWithGoogle() async throws -> User {
    let authURL = buildGoogleAuthURL()
    let code = await presentAuthWebView(url: authURL)
    let tokens = try await vibeFlowAPI.exchangeGoogleCode(code)
    try saveToKeychain(tokens)
    return try await vibeFlowAPI.getMe()
}
```

---

## Data Models (SwiftData)

### Snippet
```swift
@Model
class Snippet {
    var id: UUID
    var keyword: String        // e.g., "/standup"
    var title: String
    var content: String
    var category: String?
    var usageCount: Int
    var createdAt: Date
    var updatedAt: Date
}
```

### DictionaryEntry
```swift
@Model
class DictionaryEntry {
    var id: UUID
    var word: String           // Correct spelling
    var pronunciation: String? // Phonetic hint for LLM
    var category: String?      // tech, names, company
    var isEnabled: Bool
    var createdAt: Date
}
```

### UsageSession
```swift
@Model
class UsageSession {
    var id: UUID
    var date: Date
    var wordCount: Int
    var durationSeconds: Double
    var wasLLMProcessed: Bool
    var snippetsUsed: [String]
    var mode: String           // "hold" or "toggle"
}
```

---

## File Structure

```
VibeFlow/
├── App/
│   ├── VibeFlowApp.swift           # App entry point
│   └── RootView.swift               # Navigation coordinator
│
├── Models/
│   ├── AppSettings.swift            # User preferences
│   ├── TranscriptionEntry.swift     # History persistence
│   ├── Snippet.swift                # Text expansion templates
│   ├── DictionaryEntry.swift        # Custom vocabulary
│   ├── UsageSession.swift           # Stats tracking
│   └── NavigationItem.swift         # Sidebar navigation
│
├── Services/
│   ├── ConversationController.swift # Hotkey handling, workflow
│   ├── SpeechManager.swift          # Audio recording & transcription
│   ├── VibeFlowAPIClient.swift      # Managed backend integration
│   ├── AuthManager.swift            # Authentication & SSO
│   ├── SnippetManager.swift         # Text expansion logic
│   ├── DictionaryManager.swift      # Custom vocabulary handling
│   ├── StatsTracker.swift           # Usage analytics
│   └── PermissionsHelper.swift      # Permission checking
│
├── Views/
│   ├── Main/
│   │   ├── MainView.swift           # Navigation split view
│   │   ├── HomeView.swift           # Dashboard
│   │   ├── HistoryView.swift        # Transcription list
│   │   └── SidebarView.swift        # Navigation sidebar
│   │
│   ├── Settings/
│   │   └── SettingsView.swift       # Preferences
│   │
│   ├── HUD/
│   │   ├── HUDWaveView.swift        # Recording overlay
│   │   └── HUDInstructionsView.swift
│   │
│   ├── Snippets/
│   │   ├── SnippetsListView.swift
│   │   └── SnippetEditorView.swift
│   │
│   ├── Dictionary/
│   │   ├── DictionaryListView.swift
│   │   └── DictionaryEntryEditor.swift
│   │
│   ├── Stats/
│   │   └── StatsView.swift          # Usage dashboard
│   │
│   ├── Auth/
│   │   └── LoginView.swift
│   │
│   ├── Components/
│   │   ├── BrandHeaderView.swift
│   │   ├── StatCard.swift
│   │   ├── HistoryEntryRow.swift
│   │   └── HistoryDetailView.swift
│   │
│   └── Onboarding/
│       ├── OnboardingContainerView.swift
│       ├── WelcomeStepView.swift
│       ├── PermissionsStepView.swift
│       ├── ConfigurationStepView.swift
│       └── CompletionStepView.swift
│
├── VibeFlow.entitlements            # Sandbox entitlements
└── CLAUDE.md                        # This file
```

---

## Backend Integration

See `/WhisprFlow-backend/API_SPEC.md` for complete API documentation.

### Key Endpoints
- `POST /auth/google` - Google OAuth
- `POST /auth/microsoft` - Microsoft Entra ID OAuth
- `POST /llm/chat/completions` - Text cleanup with streaming
- `GET/POST /snippets` - Snippet management
- `GET/POST /dictionary` - Dictionary management
- `POST /stats/session` - Record usage
- `GET /stats/summary` - Get productivity metrics

---

## Development Notes

**Minimum Requirements:**
- macOS 14.0+
- Xcode 15.0+
- Swift 5.9+

**Debug Build Path:**
```
/Users/agarwalvivek29/Library/Developer/Xcode/DerivedData/VibeFlow-*/Build/Products/Debug/VibeFlow.app
```

**Testing:**
- Use Right Command (⌘) as fallback hotkey for testing
- Test Fn+Space toggle mode for long transcriptions
- Test snippet expansion with /test keyword
- Verify dictionary words are preserved in LLM output

---

## Git Commit Guidelines

- Use conventional commit format: `type: description`
- Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`
- **Do NOT add co-author lines** to commits (no `Co-Authored-By:` trailers)
- **Do NOT mention Claude or AI** in commit messages or PR descriptions
- Keep commit messages concise and focused on what changed
