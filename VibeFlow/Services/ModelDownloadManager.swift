//
//  ModelDownloadManager.swift
//  VibeFlow
//
//  Manages downloading and caching ML models (Whisper, SLM)
//

import Foundation
import os
import SwiftUI
import Combine

@MainActor
final class ModelDownloadManager: ObservableObject {

    // MARK: - Types

    typealias WhisperModelSize = AppSettings.WhisperModelSize

    enum ModelType: Equatable {
        case whisper(WhisperModelSize)
        case slm
    }

    enum DownloadState: Equatable {
        case notDownloaded
        case downloading(progress: Double)
        case downloaded
        case error(String)
    }

    // MARK: - Published state

    @Published var whisperStates: [WhisperModelSize: DownloadState] = [:]
    @Published var slmState: DownloadState = .notDownloaded

    // MARK: - Storage

    private(set) var modelsDirectory: URL

    private static let slmCacheDir: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".cache/huggingface/hub/models--mlx-community--Qwen2.5-0.5B-Instruct-4bit")
    }()

    // MARK: - Init

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        modelsDirectory = appSupport.appendingPathComponent("WhisprFlow/Models")
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)

        for size in WhisperModelSize.allCases {
            whisperStates[size] = .notDownloaded
        }
        checkExistingModels()
    }

    // MARK: - Public API

    func checkExistingModels() {
        for size in WhisperModelSize.allCases {
            let path = modelsDirectory.appendingPathComponent(size.fileName)
            if FileManager.default.fileExists(atPath: path.path) {
                whisperStates[size] = .downloaded
            } else if case .downloading = whisperStates[size] {
                // preserve in-flight download progress
            } else {
                whisperStates[size] = .notDownloaded
            }
        }

        if FileManager.default.fileExists(atPath: Self.slmCacheDir.path) {
            slmState = .downloaded
        } else if case .downloading = slmState {
            // preserve in-flight state
        } else {
            slmState = .notDownloaded
        }
    }

    func state(for type: ModelType) -> DownloadState {
        switch type {
        case .whisper(let size):
            return whisperStates[size] ?? .notDownloaded
        case .slm:
            return slmState
        }
    }

    func isModelAvailable(_ type: ModelType) -> Bool {
        state(for: type) == .downloaded
    }

    func modelPath(_ type: ModelType) -> URL? {
        switch type {
        case .whisper(let size):
            let path = modelsDirectory.appendingPathComponent(size.fileName)
            return FileManager.default.fileExists(atPath: path.path) ? path : nil
        case .slm:
            return FileManager.default.fileExists(atPath: Self.slmCacheDir.path) ? Self.slmCacheDir : nil
        }
    }

    func deleteModel(_ type: ModelType) throws {
        switch type {
        case .whisper(let size):
            let path = modelsDirectory.appendingPathComponent(size.fileName)
            AppLogger.models.info("model_delete model=whisper variant=\(size.rawValue)")
            try FileManager.default.removeItem(at: path)
            whisperStates[size] = .notDownloaded
        case .slm:
            AppLogger.models.info("model_delete model=slm")
            try FileManager.default.removeItem(at: Self.slmCacheDir)
            slmState = .notDownloaded
        }
    }

    // MARK: - Downloads

    func downloadWhisperModel(size: WhisperModelSize) async {
        AppLogger.models.info("download phase=start model=whisper variant=\(size.rawValue) url=\(size.downloadURL.absoluteString)")
        whisperStates[size] = .downloading(progress: 0)
        let downloadStart = Date()

        do {
            let (asyncBytes, response) = try await URLSession.shared.bytes(from: size.downloadURL)

            let totalBytes = response.expectedContentLength
            let destinationURL = modelsDirectory.appendingPathComponent(size.fileName)
            let tempURL = modelsDirectory.appendingPathComponent(size.fileName + ".tmp")

            AppLogger.models.info("download phase=streaming model=whisper variant=\(size.rawValue) total_bytes=\(totalBytes)")

            // Remove any leftover temp file
            try? FileManager.default.removeItem(at: tempURL)

            guard let output = OutputStream(url: tempURL, append: false) else {
                AppLogger.models.error("download outcome=error model=whisper variant=\(size.rawValue) reason=failed_to_create_output_file")
                whisperStates[size] = .error("Failed to create output file")
                return
            }
            output.open()

            var downloadedBytes: Int64 = 0
            let bufferSize = 65_536
            var buffer = [UInt8]()
            buffer.reserveCapacity(bufferSize)
            var lastLoggedProgress: Double = 0

            for try await byte in asyncBytes {
                buffer.append(byte)

                if buffer.count >= bufferSize {
                    buffer.withUnsafeBufferPointer { ptr in
                        _ = output.write(ptr.baseAddress!, maxLength: ptr.count)
                    }
                    downloadedBytes += Int64(buffer.count)
                    buffer.removeAll(keepingCapacity: true)

                    if totalBytes > 0 {
                        let progress = Double(downloadedBytes) / Double(totalBytes)
                        whisperStates[size] = .downloading(progress: progress)
                        // Log at 25% milestones
                        if progress - lastLoggedProgress >= 0.25 {
                            lastLoggedProgress = (progress * 4).rounded(.down) / 4
                            AppLogger.models.info("download phase=progress model=whisper variant=\(size.rawValue) progress=\(Int(progress * 100))%")
                        }
                    }
                }
            }

            if !buffer.isEmpty {
                buffer.withUnsafeBufferPointer { ptr in
                    _ = output.write(ptr.baseAddress!, maxLength: ptr.count)
                }
            }
            output.close()

            try? FileManager.default.removeItem(at: destinationURL)
            try FileManager.default.moveItem(at: tempURL, to: destinationURL)

            let elapsed = Int(Date().timeIntervalSince(downloadStart) * 1000)
            AppLogger.models.info("download outcome=success model=whisper variant=\(size.rawValue) size_bytes=\(downloadedBytes) duration_ms=\(elapsed)")
            whisperStates[size] = .downloaded
        } catch {
            let elapsed = Int(Date().timeIntervalSince(downloadStart) * 1000)
            AppLogger.models.error("download outcome=error model=whisper variant=\(size.rawValue) error=\(error.localizedDescription) duration_ms=\(elapsed)")
            whisperStates[size] = .error(error.localizedDescription)
        }
    }

    func downloadSLMModel() async {
        // MLX models are downloaded by ModelFactory on first load.
        // We just check if the HuggingFace cache already exists.
        if FileManager.default.fileExists(atPath: Self.slmCacheDir.path) {
            AppLogger.models.info("model_check model=slm outcome=already_cached path=\(Self.slmCacheDir.path)")
            slmState = .downloaded
        } else {
            AppLogger.models.info("model_check model=slm outcome=not_cached")
            slmState = .notDownloaded
        }
    }
}
