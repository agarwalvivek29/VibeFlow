//
//  AppLogger.swift
//  VibeFlow
//
//  Centralised os.log loggers for all VibeFlow subsystems.
//  Using os.log (Logger) ensures logs survive in production builds installed
//  from the DMG — they are visible via Console.app and:
//
//    log stream --predicate 'subsystem == "com.vibeflow.app"' --level info
//    log stream --predicate 'subsystem == "com.vibeflow.app" AND category == "pipeline"'
//    log show   --predicate 'subsystem == "com.vibeflow.app"' --last 1h
//

import os.log

enum AppLogger {
    /// App lifecycle, startup, SwiftData, window management.
    static let app         = Logger(subsystem: "com.vibeflow.app", category: "app")

    /// Audio capture, device selection, sample rates, recognition engine.
    static let audio       = Logger(subsystem: "com.vibeflow.app", category: "audio")

    /// Recording pipeline: transcript, filler removal, LLM processing, clipboard.
    static let pipeline    = Logger(subsystem: "com.vibeflow.app", category: "pipeline")

    /// HUD window positioning, screen detection, state transitions.
    static let hud         = Logger(subsystem: "com.vibeflow.app", category: "hud")

    /// macOS permission requests and status (accessibility, mic, speech).
    static let permissions = Logger(subsystem: "com.vibeflow.app", category: "permissions")

    /// Model downloads, cache checks, load/unload lifecycle.
    static let models      = Logger(subsystem: "com.vibeflow.app", category: "models")
}
