//
//  PermissionsHelper.swift
//  VibeFlow
//
//  Helper to check and request macOS permissions
//

import Foundation
import os
import AppKit
import AVFoundation
import Speech

class PermissionsHelper {
    // MARK: - Accessibility
    static func checkAccessibilityPermissions() -> Bool {
        return AXIsProcessTrusted()
    }

    static func requestAccessibilityPermissions() {
        AppLogger.permissions.info("permission_request type=accessibility")
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let result = AXIsProcessTrustedWithOptions(options)
        AppLogger.permissions.info("permission_result type=accessibility granted=\(result)")

        if !result {
            AppLogger.permissions.info("permission_action type=accessibility action=opening_system_settings")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                openAccessibilityPreferences()
            }
        }
    }

    static func openAccessibilityPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
            AppLogger.permissions.info("permission_settings_opened type=accessibility method=direct_url")
        } else {
            let settingsURL = URL(fileURLWithPath: "/System/Applications/System Settings.app")
            NSWorkspace.shared.open(settingsURL)
            AppLogger.permissions.info("permission_settings_opened type=accessibility method=system_settings_fallback")
        }
    }

    // MARK: - Microphone
    static func checkMicrophonePermission() -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        return status == .authorized
    }

    static func requestMicrophonePermission() {
        AppLogger.permissions.info("permission_request type=microphone")
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            AppLogger.permissions.info("permission_result type=microphone granted=\(granted)")
            if !granted {
                AppLogger.permissions.info("permission_action type=microphone action=opening_system_settings")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    openMicrophonePreferences()
                }
            }
        }
    }

    static func openMicrophonePreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
            AppLogger.permissions.info("permission_settings_opened type=microphone method=direct_url")
        } else {
            let settingsURL = URL(fileURLWithPath: "/System/Applications/System Settings.app")
            NSWorkspace.shared.open(settingsURL)
            AppLogger.permissions.info("permission_settings_opened type=microphone method=system_settings_fallback")
        }
    }

    // MARK: - Speech Recognition
    static func checkSpeechRecognitionPermission() -> Bool {
        let status = SFSpeechRecognizer.authorizationStatus()
        return status == .authorized
    }

    static func requestSpeechRecognitionPermission() async {
        AppLogger.permissions.info("permission_request type=speech_recognition")
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                let granted = status == .authorized
                AppLogger.permissions.info("permission_result type=speech_recognition granted=\(granted) status=\(status.rawValue)")
                if status != .authorized {
                    AppLogger.permissions.info("permission_action type=speech_recognition action=opening_system_settings")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        openSpeechRecognitionPreferences()
                    }
                }
                continuation.resume()
            }
        }
    }

    static func openSpeechRecognitionPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition") {
            NSWorkspace.shared.open(url)
            AppLogger.permissions.info("permission_settings_opened type=speech_recognition method=direct_url")
        } else {
            let settingsURL = URL(fileURLWithPath: "/System/Applications/System Settings.app")
            NSWorkspace.shared.open(settingsURL)
            AppLogger.permissions.info("permission_settings_opened type=speech_recognition method=system_settings_fallback")
        }
    }
}
