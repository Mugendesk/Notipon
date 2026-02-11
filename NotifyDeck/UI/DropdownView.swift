import SwiftUI

/// ドロップダウンメニュー（クリック時）
struct DropdownView: View {
    @EnvironmentObject var storageManager: StorageManager
    @EnvironmentObject var settingsManager: SettingsManager

    let onOpenHistory: () -> Void
    let onOpenSettings: () -> Void

    private var recentNotifications: [NotificationItem] {
        Array(storageManager.notifications.prefix(20))
    }

    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            headerSection

            Divider()

            // 通知一覧
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(recentNotifications) { notification in
                        NotificationRow(notification: notification, compact: true)
                            .onTapGesture {
                                handleNotificationTap(notification)
                            }
                            .contextMenu {
                                Button(action: { openApp(notification) }) {
                                    Label("アプリを開く", systemImage: "arrow.up.forward.app")
                                }

                                Button(action: { try? storageManager.markAsRead(notification.id) }) {
                                    Label("既読にする", systemImage: "checkmark.circle")
                                }

                                Divider()

                                Button(role: .destructive, action: { try? storageManager.delete(notification.id) }) {
                                    Label("削除", systemImage: "trash")
                                }
                            }

                        if notification.id != recentNotifications.last?.id {
                            Divider()
                                .padding(.leading, 50)
                        }
                    }
                }
            }
            .frame(height: 320)

            Divider()

            // フッター
            footerSection
        }
        .frame(width: settingsManager.dropdownWidth)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Text("NotifyDeck")
                .font(.system(size: settingsManager.dropdownFontSize * 1.2, weight: .semibold))

            Spacer()

            // 未読数
            if storageManager.unreadCount > 0 {
                Text("\(storageManager.unreadCount) 件未読")
                    .font(.system(size: settingsManager.dropdownFontSize * 0.9))
                    .foregroundColor(.secondary)
            }

            Button(action: onOpenSettings) {
                Image(systemName: "gear")
                    .font(.system(size: settingsManager.dropdownFontSize))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            Button(action: markAllAsRead) {
                Label("すべて既読", systemImage: "checkmark.circle")
                    .font(.system(size: settingsManager.dropdownFontSize * 0.9))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)

            Spacer()

            Button(action: onOpenHistory) {
                Text("すべての履歴を見る →")
                    .font(.system(size: settingsManager.dropdownFontSize * 0.9))
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)

            Spacer()

            Button(action: quitApp) {
                Label("終了", systemImage: "power")
                    .font(.system(size: settingsManager.dropdownFontSize * 0.9))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Actions

    private func handleNotificationTap(_ notification: NotificationItem) {
        // 既読にする
        try? storageManager.markAsRead(notification.id)
    }

    private func openApp(_ notification: NotificationItem) {
        // アプリを開く
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: notification.appIdentifier) {
            NSWorkspace.shared.open(url)
        }
    }

    private func markAllAsRead() {
        try? storageManager.markAllAsRead()
    }

    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

#Preview {
    DropdownView(
        onOpenHistory: {},
        onOpenSettings: {}
    )
    .environmentObject(StorageManager.shared)
    .environmentObject(SettingsManager.shared)
}
