//
//  NavigationItem.swift
//  VibeFlow
//
//  Navigation items for the sidebar
//

import Foundation

enum NavigationItem: String, CaseIterable, Identifiable {
    case dashboard
    case history
    case dictionary
    case settings

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2.fill"
        case .history: return "clock.fill"
        case .dictionary: return "character.book.closed.fill"
        case .settings: return "gearshape.fill"
        }
    }

    var label: String {
        rawValue.capitalized
    }
}
