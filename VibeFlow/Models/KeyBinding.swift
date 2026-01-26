//
//  KeyBinding.swift
//  VibeFlow
//
//  Data model for configurable key bindings
//

import Foundation
#if os(macOS)
import AppKit
import Carbon.HIToolbox
#endif

struct KeyBinding: Codable, Equatable {
    let keyCode: UInt16
    let modifiers: UInt
    let isModifierOnly: Bool

    var displayString: String {
        #if os(macOS)
        var parts: [String] = []

        let flags = NSEvent.ModifierFlags(rawValue: modifiers)

        if flags.contains(.control) {
            parts.append("⌃")
        }
        if flags.contains(.option) {
            parts.append("⌥")
        }
        if flags.contains(.shift) {
            parts.append("⇧")
        }
        if flags.contains(.command) {
            // Distinguish left vs right command
            if keyCode == 54 {
                parts.append("Right ⌘")
            } else if keyCode == 55 {
                parts.append("Left ⌘")
            } else {
                parts.append("⌘")
            }
        }
        if flags.contains(.function) {
            parts.append("Fn")
        }

        if !isModifierOnly {
            parts.append(Self.keyCodeToString(keyCode))
        }

        return parts.isEmpty ? "None" : parts.joined(separator: "+")
        #else
        return "N/A"
        #endif
    }

    #if os(macOS)
    static func keyCodeToString(_ keyCode: UInt16) -> String {
        switch Int(keyCode) {
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Space: return "Space"
        case kVK_Delete: return "⌫"
        case kVK_Escape: return "⎋"
        case kVK_ForwardDelete: return "⌦"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_DownArrow: return "↓"
        case kVK_UpArrow: return "↑"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        case kVK_Home: return "↖"
        case kVK_End: return "↘"
        case kVK_PageUp: return "⇞"
        case kVK_PageDown: return "⇟"
        case 54: return "" // Right Command (handled in modifiers)
        case 55: return "" // Left Command (handled in modifiers)
        default:
            // Convert keyCode to character
            if let char = keyCodeToCharacter(keyCode) {
                return char.uppercased()
            }
            return "Key(\(keyCode))"
        }
    }

    private static func keyCodeToCharacter(_ keyCode: UInt16) -> String? {
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        guard let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let dataRef = unsafeBitCast(layoutData, to: CFData.self)
        let keyboardLayout = unsafeBitCast(CFDataGetBytePtr(dataRef), to: UnsafePointer<UCKeyboardLayout>.self)

        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length: Int = 0

        let result = UCKeyTranslate(
            keyboardLayout,
            keyCode,
            UInt16(kUCKeyActionDown),
            0,
            UInt32(LMGetKbdType()),
            UInt32(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            chars.count,
            &length,
            &chars
        )

        if result == noErr && length > 0 {
            return String(utf16CodeUnits: chars, count: length)
        }
        return nil
    }
    #endif

    // MARK: - Static Presets

    #if os(macOS)
    static let fnKey = KeyBinding(
        keyCode: 0,
        modifiers: NSEvent.ModifierFlags.function.rawValue,
        isModifierOnly: true
    )

    static let rightCommand = KeyBinding(
        keyCode: 54,
        modifiers: NSEvent.ModifierFlags.command.rawValue,
        isModifierOnly: true
    )

    static let cmdV = KeyBinding(
        keyCode: 9, // V key
        modifiers: NSEvent.ModifierFlags.command.rawValue,
        isModifierOnly: false
    )
    #else
    static let fnKey = KeyBinding(keyCode: 0, modifiers: 0, isModifierOnly: true)
    static let rightCommand = KeyBinding(keyCode: 54, modifiers: 0, isModifierOnly: true)
    static let cmdV = KeyBinding(keyCode: 9, modifiers: 0, isModifierOnly: false)
    #endif
}

// MARK: - Recording Key Preset

enum RecordingKeyPreset: String, CaseIterable, Codable {
    case fn = "Fn Key"
    case rightCommand = "Right Command"
    case custom = "Custom"

    var keyBinding: KeyBinding? {
        switch self {
        case .fn:
            return .fnKey
        case .rightCommand:
            return .rightCommand
        case .custom:
            return nil
        }
    }

    var description: String {
        switch self {
        case .fn:
            return "Use the Fn key to trigger recording"
        case .rightCommand:
            return "Use the Right Command key to trigger recording"
        case .custom:
            return "Set a custom key combination"
        }
    }
}

// MARK: - Post Transcription Action

enum PostTranscriptionAction: String, CaseIterable, Codable {
    case autoPaste = "Auto-paste"
    case clipboardOnly = "Clipboard Only"
    case customKeyCombo = "Custom Key Combo"

    var description: String {
        switch self {
        case .autoPaste:
            return "Automatically paste text using Cmd+V"
        case .clipboardOnly:
            return "Copy to clipboard without pasting"
        case .customKeyCombo:
            return "Send a custom key combination after copying"
        }
    }
}
