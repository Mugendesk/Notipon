import SwiftUI

/// アプリフィルタチップ
struct AppFilterChip: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - App Filter Chip Group

struct AppFilterChipGroup: View {
    let apps: [(identifier: String, name: String, count: Int)]
    @Binding var selectedApps: Set<String>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // すべて
                AppFilterChip(
                    name: "すべて",
                    isSelected: selectedApps.isEmpty,
                    action: { selectedApps.removeAll() }
                )

                // アプリ別
                ForEach(apps, id: \.identifier) { app in
                    AppFilterChip(
                        name: app.name,
                        isSelected: selectedApps.contains(app.identifier),
                        action: {
                            if selectedApps.contains(app.identifier) {
                                selectedApps.remove(app.identifier)
                            } else {
                                selectedApps.insert(app.identifier)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}

#Preview {
    VStack {
        AppFilterChip(name: "Slack", isSelected: true, action: {})
        AppFilterChip(name: "Mail", isSelected: false, action: {})

        AppFilterChipGroup(
            apps: [
                ("com.slack", "Slack", 10),
                ("com.apple.mail", "Mail", 5),
                ("com.discord", "Discord", 3)
            ],
            selectedApps: .constant(["com.slack"])
        )
    }
    .padding()
}
