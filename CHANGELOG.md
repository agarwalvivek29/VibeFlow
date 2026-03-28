# Changelog

All notable changes to WhisprFlow are documented here.

## [1.2] - 2026-03-28

### Added
- In-app appearance toggle (Light / Dark / System) in Settings — persists across launches via UserDefaults
- History detail sheet — tap any transcription to open a full-screen detail view with Speed and Duration metadata
- Average WPM stat on the Dashboard alongside word count and session count

### Changed
- All views now use adaptive NSColor-backed colors (`windowBackgroundColor`, `controlBackgroundColor`) so the UI renders correctly in both Light and Dark mode
- Sidebar app logo enlarged 20% (28 → 34 pt) for better visual presence
- Formality setting removed from Settings (redundant with writing style)
- Microphone permissions prompt moved to the top of Settings for discoverability

### Fixed
- "Publishing changes from within view updates is not allowed" warning eliminated — the appearance Picker's binding now defers writes to the next run loop iteration via `DispatchQueue.main.async`
- 300 ms grace delay added before `stopAndWaitForFinal()` to capture trailing speech and reduce cut-off words at end of recordings
- `llmModel` field in transcription history now accurately reflects no-processing (empty), local SLM (`Qwen2.5-0.5B`), or remote model name
- Window resizability set to automatic so the window remembers its size between launches

## [1.1] - 2026-03-20

### Added
- WhisperKit on-device speech recognition with model management UI
- Local SLM text cleanup via Qwen 2.5 0.5B (MLX)
- Custom dictionary for domain-specific term recognition
- Transcription history with search
- Settings panel with model selection, writing style, and shortcut configuration
