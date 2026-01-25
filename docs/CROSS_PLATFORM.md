# VibeFlow Cross-Platform Replication Guide

This document provides architecture specifications for implementing VibeFlow on platforms beyond macOS.

---

## Platform Support Matrix

| Feature | macOS (Current) | Windows | Linux | iOS | Android |
|---------|-----------------|---------|-------|-----|---------|
| Global Hotkey | Fn key | Win+Space | Super+Space | N/A | N/A |
| On-Device STT | Apple Speech | Windows Speech | Whisper.cpp | Apple Speech | Android Speech |
| Overlay HUD | NSPanel | Always-on-top | X11/Wayland | N/A | Overlay |
| Auto-Paste | CGEvent | SendInput | xdotool/ydotool | N/A | Accessibility |
| Auth | ASWebAuth | WebView2 | Webkit/OAuth | ASWebAuth | Chrome Custom Tabs |

---

## Core Architecture (Platform-Agnostic)

### Component Responsibilities

```
┌─────────────────────────────────────────────────────────────┐
│                     VibeFlow Client                         │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │   Hotkey    │  │    Audio    │  │   Speech-to-Text    │  │
│  │   Manager   │  │   Capture   │  │     Engine          │  │
│  │ (Platform)  │  │ (Platform)  │  │   (Platform/API)    │  │
│  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘  │
│         │                │                    │              │
│  ┌──────▼────────────────▼────────────────────▼──────────┐  │
│  │               Conversation Controller                  │  │
│  │         (Orchestration - Platform-Agnostic)           │  │
│  └──────────────────────────┬────────────────────────────┘  │
│                             │                                │
│  ┌──────────────────────────▼────────────────────────────┐  │
│  │               VibeFlow API Client                      │  │
│  │           (HTTP/WebSocket - Platform-Agnostic)         │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │  Snippet    │  │ Dictionary  │  │     Stats           │  │
│  │  Manager    │  │   Manager   │  │    Tracker          │  │
│  │  (Local DB) │  │  (Local DB) │  │   (Local DB)        │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
│                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │  HUD/UI     │  │  Auto-Paste │  │    Auth Manager     │  │
│  │ (Platform)  │  │ (Platform)  │  │    (Platform)       │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## Windows Implementation

### Tech Stack
- **Language**: C# with .NET 8 or Rust with Tauri
- **UI Framework**: WPF/WinUI 3 or WebView2
- **Database**: SQLite via Entity Framework or rusqlite

### Platform-Specific Components

#### 1. Global Hotkey Detection
```csharp
// Using Windows Raw Input API
[DllImport("user32.dll")]
static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

// Win+Space combination
RegisterHotKey(hwnd, HOTKEY_ID, MOD_WIN, VK_SPACE);

// Or using Low-Level Keyboard Hook for toggle mode
SetWindowsHookEx(WH_KEYBOARD_LL, KeyboardHookCallback, hInstance, 0);
```

#### 2. Audio Capture (WASAPI)
```csharp
// Using NAudio for WASAPI capture
var capture = new WasapiCapture();
capture.DataAvailable += (s, e) => {
    // Feed audio buffer to speech recognition
    speechRecognizer.ProcessAudio(e.Buffer);
};
capture.StartRecording();
```

#### 3. Speech Recognition
**Option A: Windows Speech Platform**
```csharp
using System.Speech.Recognition;

var recognizer = new SpeechRecognitionEngine();
recognizer.SetInputToDefaultAudioDevice();
recognizer.LoadGrammar(new DictationGrammar());
recognizer.SpeechRecognized += (s, e) => {
    var text = e.Result.Text;
};
recognizer.RecognizeAsync(RecognizeMode.Multiple);
```

**Option B: Whisper.cpp (Better Accuracy)**
```csharp
// P/Invoke to whisper.cpp or use Whisper.net wrapper
var whisper = WhisperFactory.FromPath("ggml-base.bin");
var result = await whisper.CreateBuilder()
    .WithLanguage("en")
    .ProcessAsync(audioBuffer);
```

#### 4. Overlay HUD
```csharp
// WPF Always-on-top transparent window
var hudWindow = new Window {
    WindowStyle = WindowStyle.None,
    AllowsTransparency = true,
    Background = Brushes.Transparent,
    Topmost = true,
    ShowInTaskbar = false
};

// Position at bottom center
var screen = Screen.PrimaryScreen.WorkingArea;
hudWindow.Left = (screen.Width - hudWindow.Width) / 2;
hudWindow.Top = screen.Height - hudWindow.Height - 20;
```

#### 5. Auto-Paste (SendInput)
```csharp
// Set clipboard
Clipboard.SetText(processedText);

// Simulate Ctrl+V
var inputs = new INPUT[] {
    new INPUT { type = INPUT_KEYBOARD, ki = new KEYBDINPUT { wVk = VK_CONTROL } },
    new INPUT { type = INPUT_KEYBOARD, ki = new KEYBDINPUT { wVk = 0x56 } }, // V
    new INPUT { type = INPUT_KEYBOARD, ki = new KEYBDINPUT { wVk = 0x56, dwFlags = KEYEVENTF_KEYUP } },
    new INPUT { type = INPUT_KEYBOARD, ki = new KEYBDINPUT { wVk = VK_CONTROL, dwFlags = KEYEVENTF_KEYUP } }
};
SendInput(inputs.Length, inputs, Marshal.SizeOf<INPUT>());
```

#### 6. Authentication (WebView2)
```csharp
var webView = new WebView2();
await webView.EnsureCoreWebView2Async();
webView.Source = new Uri("https://api.vibeflow.ai/auth/google/authorize");
webView.NavigationCompleted += (s, e) => {
    var url = webView.Source.ToString();
    if (url.Contains("code=")) {
        var code = ExtractAuthCode(url);
        await ExchangeCodeForTokens(code);
    }
};
```

---

## Linux Implementation

### Tech Stack
- **Language**: Rust with Tauri, or Python with PyQt/GTK
- **UI Framework**: GTK4, Qt6, or Tauri WebView
- **Database**: SQLite via rusqlite or SQLAlchemy

### Platform-Specific Components

#### 1. Global Hotkey Detection

**X11:**
```python
from Xlib import X, XK
from Xlib.display import Display

display = Display()
root = display.screen().root

# Grab Super+Space
root.grab_key(
    display.keysym_to_keycode(XK.XK_space),
    X.Mod4Mask,  # Super key
    True,
    X.GrabModeAsync,
    X.GrabModeAsync
)

while True:
    event = display.next_event()
    if event.type == X.KeyPress:
        start_recording()
```

**Wayland (using libinput or D-Bus portal):**
```python
# Use GlobalShortcuts portal
import dbus

bus = dbus.SessionBus()
portal = bus.get_object('org.freedesktop.portal.Desktop',
                         '/org/freedesktop/portal/desktop')
shortcuts = dbus.Interface(portal, 'org.freedesktop.portal.GlobalShortcuts')

shortcuts.CreateSession({})
shortcuts.BindShortcuts([("vibeflow-record", {"description": "Start recording"})])
```

#### 2. Audio Capture (PulseAudio/PipeWire)

```python
import sounddevice as sd

def audio_callback(indata, frames, time, status):
    speech_recognizer.process_audio(indata)

with sd.InputStream(callback=audio_callback, channels=1, samplerate=16000):
    # Recording active
    pass
```

#### 3. Speech Recognition (Whisper.cpp)

```python
import whisper_cpp

model = whisper_cpp.Whisper("ggml-base.bin")

def transcribe(audio_data):
    return model.transcribe(audio_data, language="en")
```

#### 4. Overlay HUD

**GTK4:**
```python
import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, Gdk

class HUDWindow(Gtk.Window):
    def __init__(self):
        super().__init__()
        self.set_decorated(False)
        self.set_opacity(0.9)
        # Make it floating
        self.set_type_hint(Gdk.WindowTypeHint.DOCK)
```

**Wayland Layer Shell:**
```rust
// Using layer-shell protocol for proper overlay
use wayland_client::protocol::wl_surface::WlSurface;
use wayland_protocols_wlr::layer_shell::v1::client::zwlr_layer_shell_v1::Layer;

layer_surface.set_layer(Layer::Overlay);
layer_surface.set_anchor(Anchor::Bottom);
```

#### 5. Auto-Paste

**X11 (xdotool):**
```python
import subprocess

# Set clipboard
subprocess.run(['xclip', '-selection', 'clipboard'], input=text.encode())

# Simulate Ctrl+V
subprocess.run(['xdotool', 'key', 'ctrl+v'])
```

**Wayland (wtype):**
```python
import subprocess

subprocess.run(['wl-copy', text])
subprocess.run(['wtype', '-M', 'ctrl', 'v', '-m', 'ctrl'])
```

---

## Mobile Implementation Notes

### iOS
- **Limitation**: No global hotkey support
- **Approach**: Dedicated app with voice button, Share Extension for paste
- **STT**: SFSpeechRecognizer (same as macOS)
- **Auth**: ASWebAuthenticationSession

### Android
- **Approach**: Accessibility Service for global trigger, Overlay permission for HUD
- **STT**: Android SpeechRecognizer or Whisper.cpp via JNI
- **Auth**: Chrome Custom Tabs

---

## Shared Components (Cross-Platform)

### API Client
The VibeFlow API client should be implemented in a cross-platform way:

```typescript
// TypeScript/JavaScript for Tauri/Electron
// Can also be generated from OpenAPI spec

class VibeFlowClient {
  private baseURL = 'https://api.vibeflow.ai/v1';
  private accessToken: string;

  async chatCompletion(messages: Message[], dictionary: string[]): AsyncGenerator<string> {
    const response = await fetch(`${this.baseURL}/llm/chat/completions`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ messages, dictionary, stream: true }),
    });

    const reader = response.body.getReader();
    // Parse SSE stream...
  }
}
```

### Local Database Schema
All platforms should use SQLite with this schema:

```sql
-- Snippets
CREATE TABLE snippets (
    id TEXT PRIMARY KEY,
    keyword TEXT NOT NULL UNIQUE,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    category TEXT,
    usage_count INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    synced_at DATETIME
);

-- Dictionary
CREATE TABLE dictionary (
    id TEXT PRIMARY KEY,
    word TEXT NOT NULL,
    pronunciation TEXT,
    category TEXT,
    is_enabled INTEGER DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    synced_at DATETIME
);

-- Usage Sessions
CREATE TABLE usage_sessions (
    id TEXT PRIMARY KEY,
    date DATETIME NOT NULL,
    word_count INTEGER NOT NULL,
    duration_seconds REAL NOT NULL,
    was_llm_processed INTEGER NOT NULL,
    snippets_used TEXT, -- JSON array
    mode TEXT NOT NULL, -- 'hold' or 'toggle'
    synced_at DATETIME
);

-- Auth Tokens
CREATE TABLE auth_tokens (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    expires_at DATETIME
);
```

---

## Platform-Specific Challenges

### Windows
1. **UAC and Admin Rights**: Global hotkey may require elevated privileges
2. **Antivirus Interference**: Keyboard hooks may be flagged
3. **Audio Device Changes**: Handle device disconnection gracefully

### Linux
1. **X11 vs Wayland**: Need separate implementations
2. **Distribution Fragmentation**: Audio APIs vary (PulseAudio vs PipeWire)
3. **Permissions**: May need polkit for accessibility

### Mobile
1. **Background Execution**: Limited on both iOS and Android
2. **Battery Drain**: Continuous audio capture is power-intensive
3. **No Global Hotkey**: Require different UX paradigm

---

## Testing Checklist

### All Platforms
- [ ] Hotkey detection works globally
- [ ] Audio capture uses correct device
- [ ] Speech-to-text transcription is accurate
- [ ] LLM API streaming works correctly
- [ ] Auto-paste functions in all apps
- [ ] HUD appears on correct monitor
- [ ] Snippets expand correctly
- [ ] Dictionary words are preserved
- [ ] Authentication flow completes
- [ ] Offline mode functions (local STT)

### Platform-Specific
- [ ] Windows: Works with UAC enabled
- [ ] Linux X11: Works with different window managers
- [ ] Linux Wayland: Works with Sway, GNOME, KDE
- [ ] macOS: Works in fullscreen apps

---

## Recommended Implementation Order

1. **Windows** (Largest market, .NET or Rust)
2. **Linux** (Developer audience, Rust/Tauri)
3. **iOS** (Natural extension of macOS)
4. **Android** (Largest mobile market)

---

*Last Updated: 2026-01-25*
