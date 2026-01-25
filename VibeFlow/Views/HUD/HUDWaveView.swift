import SwiftUI

// MARK: - NotchState

enum NotchState {
    case idle
    case recording

    var width: CGFloat {
        switch self {
        case .idle: return 80
        case .recording: return 160
        }
    }

    var height: CGFloat {
        switch self {
        case .idle: return 24
        case .recording: return 28
        }
    }
}

// MARK: - WaveformBar

struct WaveformBar: View {
    let level: Float
    let barCount: Int = 16

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(0..<barCount, id: \.self) { index in
                    let normalizedIndex = Float(index) / Float(barCount)
                    let barLevel = max(0.1, min(1.0, level * 2 - normalizedIndex * 0.5 + 0.3))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [.green, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: (geo.size.width - CGFloat(barCount - 1) * 2) / CGFloat(barCount),
                               height: geo.size.height * CGFloat(barLevel))
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .animation(.linear(duration: 0.05), value: level)
    }
}

// MARK: - HUDWaveView

struct HUDWaveView: View {
    @ObservedObject var controller: ConversationController
    @ObservedObject var settings: AppSettings

    private var notchState: NotchState {
        controller.isRecording ? .recording : .idle
    }

    var body: some View {
        ZStack {
            // Background pill
            RoundedRectangle(cornerRadius: notchState == .idle ? 12 : 16, style: .continuous)
                .fill(Color.black.opacity(0.75))
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)

            // Content
            if notchState == .idle {
                idleContent
                    .transition(.opacity)
            } else {
                recordingContent
                    .transition(.opacity)
            }
        }
        .frame(width: notchState.width, height: notchState.height)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: notchState == .recording)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(notchState == .recording ? "Recording in progress" : "Ready to record")
    }

    // MARK: - Idle State Content

    private var idleContent: some View {
        Text("•••••••••")
            .font(.system(size: 8, weight: .bold))
            .tracking(3)
            .foregroundColor(.white.opacity(0.5))
    }

    // MARK: - Recording State Content

    private var recordingContent: some View {
        HStack(spacing: 6) {
            // Mic icon
            Image(systemName: "mic.fill")
                .font(.system(size: 12))
                .foregroundColor(.white)

            // Waveform
            WaveformBar(level: controller.level)
                .frame(height: 12)

            // Bolt icon (shown only when LLM processing is disabled)
            if !settings.useLLMProcessing {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.yellow)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}

#if os(macOS)
import AppKit

final class HUDWindowController: NSWindowController {
    static let shared = HUDWindowController()

    private var hosting: NSHostingView<HUDWaveView>?
    private var currentController: ConversationController?
    private var currentSettings: AppSettings?
    private var instructionsController: HUDInstructionsWindowController?
    private var isInitialized = false

    private static let hasShownInstructionsKey = "hasShownHUDInstructions"

    private var hasShownInstructions: Bool {
        get { UserDefaults.standard.bool(forKey: Self.hasShownInstructionsKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.hasShownInstructionsKey) }
    }

    /// Initialize and show the HUD in idle state. Call this once at app startup.
    func initialize(controller: ConversationController, settings: AppSettings) {
        guard !isInitialized else { return }
        isInitialized = true
        self.currentController = controller
        self.currentSettings = settings

        print("[HUD] Initializing persistent HUD...")

        let content = HUDWaveView(controller: controller, settings: settings)

        // Use NSPanel instead of NSWindow for proper fullscreen overlay support
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 64),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear

        // Critical settings for fullscreen overlay
        panel.level = .floating
        panel.isFloatingPanel = true

        // Allow the panel to appear in fullscreen spaces
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false  // Don't hide when app loses focus
        panel.worksWhenModal = true      // Work even during modal dialogs
        panel.sharingType = .readWrite   // Allow screen recording to capture HUD
        self.window = panel

        let hosting = NSHostingView(rootView: content)
        self.hosting = hosting
        panel.contentView = hosting

        print("[HUD] HUD panel created with full-screen support")

        // Position and show
        updatePosition()
        panel.orderFrontRegardless()

        // Show instructions on first launch
        if !hasShownInstructions {
            showInstructions()
        }
    }

    /// Called when recording starts - updates position to follow active screen
    func show(controller: ConversationController, settings: AppSettings, atBottom: Bool = true) {
        print("[HUD] show() called, isRecording=\(controller.isRecording)")

        // Initialize if not already done
        if !isInitialized {
            initialize(controller: controller, settings: settings)
            return
        }

        // Update the content view with fresh bindings
        self.currentController = controller
        self.currentSettings = settings
        let content = HUDWaveView(controller: controller, settings: settings)
        let hosting = NSHostingView(rootView: content)
        self.hosting = hosting
        window?.contentView = hosting

        // Update position to follow active window/screen
        updatePosition()
        window?.orderFrontRegardless()
    }

    /// Updates the HUD position based on current state
    func updatePosition() {
        guard let window = window else { return }

        // Get the screen containing the currently focused window
        var activeScreen: NSScreen?

        // Try to get the screen of the frontmost app's main window
        if let frontApp = NSWorkspace.shared.frontmostApplication,
           let frontAppWindows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] {

            // Find the frontmost window
            for windowInfo in frontAppWindows {
                if let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? Int32,
                   ownerPID == frontApp.processIdentifier,
                   let bounds = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
                   let x = bounds["X"], let y = bounds["Y"],
                   let width = bounds["Width"], let height = bounds["Height"] {

                    // Find which screen contains this window
                    let windowCenter = CGPoint(x: x + width/2, y: y + height/2)
                    activeScreen = NSScreen.screens.first { screen in
                        screen.frame.contains(windowCenter)
                    }
                    break
                }
            }
        }

        // Fallback to mouse location if we couldn't find the active window's screen
        if activeScreen == nil {
            let mouseLocation = NSEvent.mouseLocation
            activeScreen = NSScreen.screens.first { screen in
                NSMouseInRect(mouseLocation, screen.frame, false)
            }
        }

        // Final fallback to main screen or first available screen
        guard let screen = activeScreen ?? NSScreen.main ?? NSScreen.screens.first else {
            print("[HUD] Error: No screen available!")
            return
        }

        let margin: CGFloat = 12

        // Use the state-based size for positioning
        let isRecording = currentController?.isRecording ?? false
        let notchState: NotchState = isRecording ? .recording : .idle
        let size = CGSize(width: notchState.width, height: notchState.height)

        // For full-screen apps, use the full screen frame, not visibleFrame
        // visibleFrame excludes menu bar/dock which don't exist in full-screen
        let screenFrame = screen.frame

        // Calculate position - bottom center of screen
        let x = screenFrame.minX + (screenFrame.width - size.width) / 2
        let y = screenFrame.minY + margin

        print("[HUD] Active screen: \(screen.localizedName)")
        print("[HUD] Screen frame: \(screenFrame)")
        print("[HUD] HUD position: (\(x), \(y)), size: \(size), isRecording: \(isRecording)")

        window.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }

    /// Hides the HUD completely (not typically used - HUD should stay visible)
    func hide() {
        window?.orderOut(nil)
        dismissInstructions()
    }

    private func showInstructions() {
        guard let hudWindow = window else { return }

        instructionsController = HUDInstructionsWindowController.show(above: hudWindow) { [weak self] in
            self?.hasShownInstructions = true
            self?.instructionsController = nil
        }
    }

    private func dismissInstructions() {
        instructionsController?.dismiss()
        instructionsController = nil
    }
}
#endif
