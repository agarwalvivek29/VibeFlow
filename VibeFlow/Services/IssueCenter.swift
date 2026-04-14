//
//  IssueCenter.swift
//  VibeFlow
//
//  Global issue aggregator for centralized, app-wide error visibility and actions.
//

import Foundation
import Combine

@MainActor
final class IssueCenter: ObservableObject {

    enum Source: String, Hashable {
        case speechModelLoad
        case textModelLoad
        case processing
    }

    enum Severity: String {
        case error
    }

    enum Action: String, CaseIterable, Identifiable {
        case fixNow
        case retry
        case changeModel

        var id: String { rawValue }

        var label: String {
            switch self {
            case .fixNow: return "Fix Now"
            case .retry: return "Retry"
            case .changeModel: return "Change Model"
            }
        }
    }

    struct Issue: Identifiable, Equatable {
        var id: String { source.rawValue }
        let source: Source
        let severity: Severity
        let title: String
        let message: String
        let actions: [Action]
        let createdAt: Date
        let updatedAt: Date
    }

    @Published private var activeIssueMap: [Source: Issue] = [:]

    var activeIssues: [Issue] {
        activeIssueMap.values.sorted { $0.updatedAt > $1.updatedAt }
    }

    var activeCount: Int {
        activeIssueMap.count
    }

    func syncModelStates(speech: ModelLoadState, text: ModelLoadState) {
        syncModelIssue(for: .speechModelLoad, state: speech)
        syncModelIssue(for: .textModelLoad, state: text)
    }

    func syncProcessingError(_ message: String?) {
        guard let message, !message.isEmpty else {
            resolve(.processing)
            return
        }

        upsert(
            source: .processing,
            title: "Processing Error",
            message: message,
            actions: [.changeModel]
        )
    }

    func resolve(_ source: Source) {
        activeIssueMap.removeValue(forKey: source)
    }

    func clearAll() {
        activeIssueMap.removeAll()
    }

    private func syncModelIssue(for source: Source, state: ModelLoadState) {
        switch state {
        case .failed(let message):
            upsert(
                source: source,
                title: "Model Failed to Load",
                message: message,
                actions: actionsForModelError(message)
            )
        case .loaded, .idle:
            resolve(source)
        case .loading:
            // Keep existing failed issue visible while a recovery attempt is in progress.
            break
        }
    }

    private func actionsForModelError(_ message: String) -> [Action] {
        if message.localizedCaseInsensitiveContains("corrupted") {
            return [.fixNow, .retry, .changeModel]
        }
        return [.retry, .changeModel]
    }

    private func upsert(source: Source, title: String, message: String, actions: [Action]) {
        let now = Date()
        if let existing = activeIssueMap[source] {
            if existing.message == message && existing.actions == actions && existing.title == title {
                return
            }
            activeIssueMap[source] = Issue(
                source: source,
                severity: existing.severity,
                title: title,
                message: message,
                actions: actions,
                createdAt: existing.createdAt,
                updatedAt: now
            )
        } else {
            activeIssueMap[source] = Issue(
                source: source,
                severity: .error,
                title: title,
                message: message,
                actions: actions,
                createdAt: now,
                updatedAt: now
            )
        }
    }
}
