# VibeFlow Enterprise Roadmap

> **Mission**: Where Engineers Can Truly Vibe
> **Timeline**: 1-Week Release Target
> **Base**: Fork of WhisprOSS (macOS)

---

## Release Strategy

### Priority Tiers

| Priority | Features | Rationale |
|----------|----------|-----------|
| **P0 - Critical** | Brand Revamp, Long Transcription Mode | Foundation + most requested UX improvement |
| **P1 - High** | Snippets, Custom Dictionary | Core productivity features, differentiators |
| **P2 - Medium** | Usage Statistics | Engagement + value demonstration |
| **P3 - Enterprise** | Authentication, Managed Backend | Enterprise-specific requirements |

---

## Feature Specifications

### 0. Long Transcription Mode (P0)
**Problem**: Holding Fn key for 5-10 minute transcriptions is impractical.

**Solution**: Toggle mode activation
- **Trigger**: `Fn + Space` pressed together
- **Behavior**: Starts recording, continues until `Fn` OR `Space` is pressed again
- **UI Indicator**: HUD shows "Recording..." with timer, pulsing indicator
- **Auto-stop**: Optional timeout (e.g., 30 min safety limit)

**Implementation**:
```
Location: Services/ConversationController.swift
Changes:
  - Add recording mode enum: .hold | .toggle
  - Modify keyDown/keyUp event handling for toggle detection
  - Add toggle state management
  - Update HUD to show recording duration
```

---

### 1. Authentication System (P3)
**Problem**: Enterprise needs user identity and license management.

**Solution**: OAuth/SSO integration with managed backend
- **Providers**: Google Workspace, Microsoft Entra ID, Okta (future)
- **Flow**: In-app browser auth → token storage in Keychain
- **License Check**: Validate subscription on app launch

**Implementation**:
```
New Files:
  - Services/AuthManager.swift
  - Services/KeychainHelper.swift
  - Views/Auth/LoginView.swift
  - Views/Auth/AuthCallbackHandler.swift
  - Models/User.swift
  - Models/License.swift
```

**Backend Requirements**:
- Auth endpoint (OAuth callback handler)
- License validation endpoint
- User provisioning API (for admin dashboard - future)

---

### 2. Remove Custom Endpoint Settings (P3)
**Problem**: Enterprise users shouldn't configure their own LLM endpoints.

**Solution**: Managed VibeFlow backend
- Remove API key input from Settings
- Remove custom endpoint URL input
- All LLM requests route through VibeFlow API (authenticated)
- Backend handles LLM provider selection and billing

**Implementation**:
```
Location: Views/Settings/SettingsView.swift
Changes:
  - Remove LiteLLM configuration section
  - Add "Powered by VibeFlow AI" badge
  - Keep local transcription toggle (Apple Speech)

Location: Services/LiteLLMClient.swift
Changes:
  - Hardcode VibeFlow API endpoint
  - Add auth token to requests
  - Remove user-configurable base URL
```

---

### 3. Snippets (P1)
**Problem**: Engineers repeatedly type the same boilerplate, commands, or responses.

**Solution**: Keyword-triggered text expansion
- **Definition**: User creates snippets with trigger keywords
- **Activation**: Type keyword → automatically expands OR suggested via HUD
- **Storage**: Local (SwiftData) + Cloud sync (future)

**Example Snippets**:
| Keyword | Expansion |
|---------|-----------|
| `/standup` | "Yesterday I worked on... Today I'm planning to... Blockers: none" |
| `/lgtm` | "Looks good to me! Approved. Consider adding tests for edge cases." |
| `/k8s-debug` | "kubectl get pods -n $NAMESPACE && kubectl logs -f $POD" |

**Implementation**:
```
New Files:
  - Models/Snippet.swift (SwiftData model)
  - Views/Snippets/SnippetsListView.swift
  - Views/Snippets/SnippetEditorView.swift
  - Services/SnippetManager.swift

Integration Points:
  - ConversationController: Detect snippet triggers in transcribed text
  - Post-transcription hook: Check for keyword matches, expand if found
  - Settings: Snippet management UI
```

**Data Model**:
```swift
@Model
class Snippet {
    var id: UUID
    var keyword: String        // Trigger text (e.g., "/standup")
    var title: String          // Display name
    var content: String        // Expansion text
    var category: String?      // Optional grouping
    var usageCount: Int        // Analytics
    var createdAt: Date
    var updatedAt: Date
}
```

---

### 4. Custom Dictionary (P1)
**Problem**: Technical terms, names, and jargon are often misrecognized.

**Solution**: User-defined vocabulary with phonetic hints
- **Dictionary Entries**: Word + optional pronunciation guide
- **Integration**: Feed to LLM cleanup prompt for correction
- **Learning**: Suggest additions based on frequent manual corrections

**Example Entries**:
| Word | Pronunciation Hint | Category |
|------|-------------------|----------|
| Kubernetes | "koo-ber-net-eez" | Tech |
| kubectl | "kube-control" | Tech |
| Vivek | "vih-vek" | Name |
| LiteLLM | "lite-L-L-M" | Tech |

**Implementation**:
```
New Files:
  - Models/DictionaryEntry.swift (SwiftData model)
  - Views/Dictionary/DictionaryListView.swift
  - Views/Dictionary/DictionaryEntryEditor.swift
  - Services/DictionaryManager.swift

Integration Points:
  - LiteLLMClient: Inject dictionary into cleanup prompt
  - Prompt Template: "The following technical terms should be spelled exactly: {dictionary_words}"
  - Settings: Dictionary management UI
```

**Data Model**:
```swift
@Model
class DictionaryEntry {
    var id: UUID
    var word: String              // Correct spelling
    var pronunciation: String?    // Phonetic hint for LLM
    var category: String?         // Tech, Names, Company, etc.
    var isEnabled: Bool
    var createdAt: Date
}
```

---

### 5. Usage Statistics (P2)
**Problem**: Users don't see the value VibeFlow provides.

**Solution**: Dashboard showing productivity metrics
- **Words Per Minute**: Average speaking → typing speed
- **Time Saved**: Estimated based on typing speed baseline (40 WPM default)
- **Daily/Weekly Stats**: Transcription count, total words, active time
- **Streaks**: Gamification for engagement

**Metrics to Track**:
| Metric | Calculation |
|--------|-------------|
| Words Transcribed | Count from each session |
| Time Saved | (word_count / 40 WPM) - actual_transcription_time |
| Sessions Today | Count of transcription completions |
| Average WPM | Total words / Total transcription time |
| Streak | Consecutive days with 1+ transcription |

**Implementation**:
```
New Files:
  - Models/UsageStats.swift (SwiftData model)
  - Views/Stats/StatsView.swift
  - Views/Stats/StatsDashboardView.swift
  - Services/StatsTracker.swift

Integration Points:
  - ConversationController: Log stats after each transcription
  - Home View: Show summary stats cards
  - Sidebar: Add "Stats" navigation item
```

**Data Model**:
```swift
@Model
class UsageSession {
    var id: UUID
    var date: Date
    var wordCount: Int
    var durationSeconds: Double
    var wasLLMProcessed: Bool
    var snippetsUsed: [String]   // Snippet keywords triggered
}

// Computed aggregates stored for performance
@Model
class DailyStats {
    var date: Date
    var totalWords: Int
    var totalSessions: Int
    var totalDurationSeconds: Double
    var estimatedTimeSavedSeconds: Double
}
```

---

## Brand Revamp Checklist

### Visual Identity
- [ ] App Name: WhisprOSS → VibeFlow
- [ ] Bundle ID: agarwalvivek29.WhisprOSS → com.vibeflow.app
- [ ] App Icon: Update with VibeFlow branding
- [ ] Color Scheme: Review and update accent colors
- [ ] Typography: Update branded text components

### Code Changes (56 touchpoints)
- [ ] Rename `WhisprOSS/` directory → `VibeFlow/`
- [ ] Rename `WhisprOSSApp.swift` → `VibeFlowApp.swift`
- [ ] Rename `WhisprOSS.entitlements` → `VibeFlow.entitlements`
- [ ] Update all file headers (26 files)
- [ ] Update UI text in views (12 files)
- [ ] Update onboarding screens (5 files)
- [ ] Update Info.plist strings
- [ ] Update project.pbxproj (16+ references)
- [ ] Update README.md
- [ ] Update Claude.md

### New Branding Elements
- [ ] Tagline: "Where Engineers Can Truly Vibe"
- [ ] Enterprise badge/indicator in UI
- [ ] "Powered by VibeFlow AI" for LLM features

---

## Architecture Changes

### Current Architecture
```
┌─────────────────┐     ┌─────────────────┐
│   SwiftUI App   │────▶│ Apple Speech    │
│   (WhisprOSS)   │     │ Recognition     │
└────────┬────────┘     └─────────────────┘
         │
         ▼
┌─────────────────┐     ┌─────────────────┐
│ Conversation    │────▶│ LiteLLM API     │
│ Controller      │     │ (User Config)   │
└─────────────────┘     └─────────────────┘
```

### Enterprise Architecture
```
┌─────────────────┐     ┌─────────────────┐
│   SwiftUI App   │────▶│ Apple Speech    │
│   (VibeFlow)    │     │ Recognition     │
└────────┬────────┘     └─────────────────┘
         │
         ▼
┌─────────────────┐     ┌─────────────────┐
│ Auth Manager    │────▶│ VibeFlow Auth   │
│                 │     │ (OAuth/SSO)     │
└────────┬────────┘     └─────────────────┘
         │
         ▼
┌─────────────────┐     ┌─────────────────┐
│ Conversation    │────▶│ VibeFlow API    │
│ Controller      │     │ (Managed LLM)   │
└────────┬────────┘     └─────────────────┘
         │
         ▼
┌─────────────────┐     ┌─────────────────┐
│ Stats Tracker   │────▶│ SwiftData       │
│ + Snippets      │     │ (Local + Sync)  │
└─────────────────┘     └─────────────────┘
```

---

## 1-Week Sprint Plan

### Day 1-2: Foundation
- [ ] Complete brand revamp (all 56 touchpoints)
- [ ] Implement long transcription toggle mode
- [ ] Set up new SwiftData models for features

### Day 3-4: Core Features
- [ ] Build Snippets feature (CRUD + integration)
- [ ] Build Custom Dictionary (CRUD + LLM integration)
- [ ] Add navigation for new features

### Day 5-6: Polish & Enterprise
- [ ] Build Usage Statistics dashboard
- [ ] Implement Authentication scaffolding
- [ ] Managed backend integration (if backend ready)

### Day 7: Release Prep
- [ ] Testing and bug fixes
- [ ] Documentation updates
- [ ] Build and notarize for distribution

---

## Cross-Platform Documentation Requirements

For replicating VibeFlow on other platforms, document:

1. **Core Concepts**
   - Hotkey detection patterns
   - Audio capture and streaming
   - Speech-to-text integration points
   - LLM API integration patterns

2. **Platform-Specific Challenges**
   - Windows: Global hotkeys, audio APIs (WASAPI)
   - Linux: X11/Wayland differences, PulseAudio/PipeWire
   - Mobile: Background audio, system integration limits

3. **Feature Parity Matrix**
   - Which features are platform-dependent
   - Alternative implementations for each platform

4. **API Contracts**
   - VibeFlow backend API specification
   - Authentication flow for each platform
   - Data sync protocols

---

## Success Metrics

| Metric | Target |
|--------|--------|
| Brand touchpoints updated | 56/56 |
| Core features complete | 4/4 (Toggle, Snippets, Dictionary, Stats) |
| Enterprise features | 2/2 (Auth, Managed Backend) |
| Cross-platform docs | Complete architecture guide |
| Build passing | Yes |
| App notarized | Yes |

---

*Last Updated: 2026-01-25*
*Version: 0.1.0-enterprise*
