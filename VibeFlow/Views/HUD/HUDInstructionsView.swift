//
//  HUDInstructionsView.swift
//  VibeFlow
//
//  First-launch instructions overlay for the notch HUD
//

import SwiftUI
#if os(macOS)
import AppKit

struct HUDInstructionsView: View {
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("Click or hold fn to start dictating")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)

            Image(systemName: "arrow.down")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.85))
        )
        .onTapGesture {
            onDismiss()
        }
    }
}

final class HUDInstructionsWindowController: NSWindowController {
    private var dismissTimer: Timer?
    private var onDismissCallback: (() -> Void)?

    static func show(above hudWindow: NSWindow?, onDismiss: @escaping () -> Void) -> HUDInstructionsWindowController {
        let controller = HUDInstructionsWindowController()
        controller.onDismissCallback = onDismiss

        let content = HUDInstructionsView(onDismiss: { [weak controller] in
            controller?.dismiss()
        })

        // Use NSPanel for proper fullscreen overlay support
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 60),
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

        panel.hasShadow = true
        panel.ignoresMouseEvents = false
        panel.hidesOnDeactivate = false

        let hosting = NSHostingView(rootView: content)
        panel.contentView = hosting
        controller.window = panel

        // Position above the HUD
        if let hudWindow = hudWindow {
            let hudFrame = hudWindow.frame
            let size = hosting.intrinsicContentSize
            let x = hudFrame.midX - size.width / 2
            let y = hudFrame.maxY + 12
            panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
        } else {
            // Fallback: center on main screen
            if let screen = NSScreen.main {
                let size = hosting.intrinsicContentSize
                let x = screen.visibleFrame.midX - size.width / 2
                let y = screen.visibleFrame.minY + 100
                panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
            }
        }

        panel.orderFrontRegardless()

        // Auto-dismiss after 5 seconds
        controller.dismissTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak controller] _ in
            controller?.dismiss()
        }

        return controller
    }

    func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        window?.orderOut(nil)
        onDismissCallback?()
    }
}
#endif

#Preview {
    HUDInstructionsView(onDismiss: {})
        .padding()
        .background(Color.gray)
}
