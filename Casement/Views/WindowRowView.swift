import SwiftUI

struct WindowRowView: View {
    let ranked: RankedWindow
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            appIcon
            VStack(alignment: .leading, spacing: 2) {
                Text(ranked.window.title)
                    .font(.system(size: 14))
                    .lineLimit(1)
                Text(ranked.window.appName)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            badges
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
    }

    private var appIcon: some View {
        Group {
            if let app = NSRunningApplication(processIdentifier: ranked.window.pid),
               let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 28, height: 28)
    }

    @ViewBuilder
    private var badges: some View {
        HStack(spacing: 4) {
            if ranked.window.isMinimized {
                BadgeView(text: "minimized", color: .orange)
            }
            if ranked.window.isFocused {
                BadgeView(text: "active", color: .green)
            }
        }
    }
}

private struct BadgeView: View {
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
