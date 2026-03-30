import SwiftUI

struct SearchResultRowView: View {
    let item: SearchResultItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            appIcon
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 14))
                        .lineLimit(1)
                    kindBadge
                }
                HStack(spacing: 4) {
                    Text(secondaryText)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if let reasons = matchLabel, !reasons.isEmpty {
                        Text(reasons)
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            Spacer()
            badges
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
    }

    private var secondaryText: String {
        switch item {
        case .window(let w):
            return w.window.title.isEmpty ? "" : w.window.appName
        case .tab(let t):
            return t.subtitle.isEmpty ? t.appName : "\(t.appName) · \(t.subtitle)"
        }
    }

    private var matchLabel: String? {
        switch item {
        case .window(let w):
            let positiveReasons = w.matchReasons.filter {
                switch $0 {
                case .minimizedPenalty, .hiddenAppPenalty, .utilityPenalty: return false
                default: return true
                }
            }
            let label = positiveReasons.map(\.description).joined(separator: " · ")
            return label.isEmpty ? nil : label
        case .tab:
            return nil
        }
    }

    @ViewBuilder
    private var kindBadge: some View {
        switch item.kind {
        case .chromeTab:
            BadgeView(text: "tab", color: .blue)
        case .terminalTab:
            BadgeView(text: "workspace", color: .purple)
        case .window:
            EmptyView()
        }
    }

    private var appIcon: some View {
        Group {
            switch item {
            case .window(let w):
                if let app = NSRunningApplication(processIdentifier: w.window.pid),
                   let icon = app.icon {
                    Image(nsImage: icon).resizable()
                } else {
                    fallbackIcon
                }
            case .tab(let t):
                if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: t.bundleId) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                        .resizable()
                } else {
                    fallbackIcon
                }
            }
        }
        .frame(width: 28, height: 28)
    }

    private var fallbackIcon: some View {
        Image(systemName: "app.fill")
            .resizable()
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var badges: some View {
        switch item {
        case .window(let w):
            HStack(spacing: 4) {
                if w.window.isMinimized {
                    BadgeView(text: "minimized", color: .orange)
                }
                if w.window.isFocused {
                    BadgeView(text: "active", color: .green)
                }
            }
        case .tab:
            EmptyView()
        }
    }
}

struct BadgeView: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .medium))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}
