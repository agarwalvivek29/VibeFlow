//
//  KeyCaptureView.swift
//  VibeFlow
//
//  UI component for capturing key bindings
//

import SwiftUI
#if os(macOS)
import AppKit
import Carbon.HIToolbox
#endif

struct KeyCaptureView: View {
    @Binding var keyBinding: KeyBinding?
    @State private var isCapturing = false
    @State private var showWarning = false
    @State private var warningMessage = ""

    var body: some View {
        HStack(spacing: 12) {
            // Display current binding
            Text(keyBinding?.displayString ?? "Not set")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(keyBinding != nil ? .primary : .secondary)
                .frame(minWidth: 100, alignment: .leading)

            // Record/Stop button
            Button(action: {
                isCapturing.toggle()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: isCapturing ? "stop.circle.fill" : "record.circle")
                        .foregroundColor(isCapturing ? .red : .accentColor)
                    Text(isCapturing ? "Stop" : "Record")
                }
            }
            .buttonStyle(.bordered)

            // Clear button
            if keyBinding != nil {
                Button(action: {
                    keyBinding = nil
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear key binding")
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isCapturing ? Color.red.opacity(0.1) : Color.secondary.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isCapturing ? Color.red : Color.clear, lineWidth: 2)
        )
        .background(
            KeyCaptureNSViewRepresentable(
                isCapturing: $isCapturing,
                keyBinding: $keyBinding,
                showWarning: $showWarning,
                warningMessage: $warningMessage
            )
        )
        .alert("Key Binding Warning", isPresented: $showWarning) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(warningMessage)
        }
    }
}

#if os(macOS)
struct KeyCaptureNSViewRepresentable: NSViewRepresentable {
    @Binding var isCapturing: Bool
    @Binding var keyBinding: KeyBinding?
    @Binding var showWarning: Bool
    @Binding var warningMessage: String

    func makeNSView(context: Context) -> KeyCaptureNSView {
        let view = KeyCaptureNSView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {
        nsView.isCapturing = isCapturing
        if isCapturing {
            nsView.window?.makeFirstResponder(nsView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator {
        var parent: KeyCaptureNSViewRepresentable

        init(_ parent: KeyCaptureNSViewRepresentable) {
            self.parent = parent
        }

        func handleKeyCapture(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, isModifierOnly: Bool) {
            // Validate the key binding
            if let warning = validateKeyBinding(keyCode: keyCode, modifiers: modifiers, isModifierOnly: isModifierOnly) {
                parent.warningMessage = warning
                parent.showWarning = true
                return
            }

            let binding = KeyBinding(
                keyCode: keyCode,
                modifiers: modifiers.rawValue,
                isModifierOnly: isModifierOnly
            )

            DispatchQueue.main.async {
                self.parent.keyBinding = binding
                self.parent.isCapturing = false
            }
        }

        private func validateKeyBinding(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, isModifierOnly: Bool) -> String? {
            // Reject certain keys that would be problematic
            let code = Int(keyCode)

            // Escape alone is not allowed (too easy to accidentally press)
            if code == kVK_Escape && isModifierOnly {
                return "Escape key alone is not recommended as it's commonly used to cancel operations."
            }

            // Space alone is not allowed
            if code == kVK_Space && modifiers.isEmpty {
                return "Space key alone is not allowed as a recording trigger."
            }

            // Warn about system shortcuts
            if modifiers.contains(.command) && !isModifierOnly {
                let systemShortcuts: [Int: String] = [
                    kVK_ANSI_Q: "Cmd+Q (Quit)",
                    kVK_ANSI_W: "Cmd+W (Close Window)",
                    kVK_ANSI_H: "Cmd+H (Hide)",
                    kVK_ANSI_M: "Cmd+M (Minimize)",
                    kVK_Tab: "Cmd+Tab (App Switcher)"
                ]

                if let conflictName = systemShortcuts[code] {
                    return "Warning: \(conflictName) is a system shortcut. This may conflict with normal usage."
                }
            }

            return nil
        }
    }
}

class KeyCaptureNSView: NSView {
    var isCapturing = false
    weak var coordinator: KeyCaptureNSViewRepresentable.Coordinator?

    private var previousModifiers: NSEvent.ModifierFlags = []

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard isCapturing else {
            super.keyDown(with: event)
            return
        }

        // Capture key with modifiers
        coordinator?.handleKeyCapture(
            keyCode: event.keyCode,
            modifiers: event.modifierFlags.intersection([.control, .option, .shift, .command, .function]),
            isModifierOnly: false
        )
    }

    override func flagsChanged(with event: NSEvent) {
        guard isCapturing else {
            super.flagsChanged(with: event)
            return
        }

        let currentModifiers = event.modifierFlags.intersection([.control, .option, .shift, .command, .function])
        let previousMods = previousModifiers

        // Detect which modifier was just released (for modifier-only bindings)
        // We want to capture on release to know it was pressed alone

        // Check for Fn key release
        let fnWasPressed = previousMods.contains(.function)
        let fnIsPressed = currentModifiers.contains(.function)

        if fnWasPressed && !fnIsPressed && previousMods.subtracting(.function).isEmpty {
            coordinator?.handleKeyCapture(
                keyCode: 0,
                modifiers: NSEvent.ModifierFlags.function,
                isModifierOnly: true
            )
            previousModifiers = currentModifiers
            return
        }

        // Check for Command key release (distinguish left/right)
        let cmdWasPressed = previousMods.contains(.command)
        let cmdIsPressed = currentModifiers.contains(.command)

        if cmdWasPressed && !cmdIsPressed && previousMods.subtracting(.command).isEmpty {
            // Check keyCode to distinguish left (55) vs right (54) command
            let keyCode = event.keyCode
            coordinator?.handleKeyCapture(
                keyCode: keyCode,
                modifiers: NSEvent.ModifierFlags.command,
                isModifierOnly: true
            )
            previousModifiers = currentModifiers
            return
        }

        // Check for Control key release
        let ctrlWasPressed = previousMods.contains(.control)
        let ctrlIsPressed = currentModifiers.contains(.control)

        if ctrlWasPressed && !ctrlIsPressed && previousMods.subtracting(.control).isEmpty {
            coordinator?.handleKeyCapture(
                keyCode: event.keyCode,
                modifiers: NSEvent.ModifierFlags.control,
                isModifierOnly: true
            )
            previousModifiers = currentModifiers
            return
        }

        // Check for Option key release
        let optWasPressed = previousMods.contains(.option)
        let optIsPressed = currentModifiers.contains(.option)

        if optWasPressed && !optIsPressed && previousMods.subtracting(.option).isEmpty {
            coordinator?.handleKeyCapture(
                keyCode: event.keyCode,
                modifiers: NSEvent.ModifierFlags.option,
                isModifierOnly: true
            )
            previousModifiers = currentModifiers
            return
        }

        previousModifiers = currentModifiers
    }
}
#else
// Stub for non-macOS platforms
struct KeyCaptureNSViewRepresentable: View {
    @Binding var isCapturing: Bool
    @Binding var keyBinding: KeyBinding?
    @Binding var showWarning: Bool
    @Binding var warningMessage: String

    var body: some View {
        EmptyView()
    }
}
#endif

#Preview {
    struct PreviewWrapper: View {
        @State private var binding: KeyBinding? = nil

        var body: some View {
            VStack(spacing: 20) {
                Text("Custom Recording Key")
                    .font(.headline)
                KeyCaptureView(keyBinding: $binding)
            }
            .padding()
            .frame(width: 300)
        }
    }

    return PreviewWrapper()
}
