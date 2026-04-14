# Changelog

All notable changes to VibeFlow are documented here.

## [1.3] - 2026-04-14

### Added
- Global Issue Center accessible from the top-right across all pages, with centralized error visibility and actions
- Issue indicator pulse animation when new active issues appear
- Issue panel actions for model recovery: `Fix Now`, `Retry`, and `Change Model`

### Changed
- Dashboard-local model load error banner removed in favor of strict centralized issue handling
- Model cache path handling aligned with app container cache location for debug app flows
- HUD error pill expanded to support longer two-line messages without truncation

### Fixed
- Recording is blocked while model(s) are loading to avoid race-condition transcription attempts
- Model loading state is shown in HUD (`Loading model…`) during preload/recovery
- Model load and processing failures now surface user-friendly messages instead of raw MLX internals
- Stale failed model state auto-clears after first successful SLM inference

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
