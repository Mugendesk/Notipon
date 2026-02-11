import SwiftUI

/// 履歴ウィンドウ（全画面）
struct HistoryWindowView: View {
    @EnvironmentObject var storageManager: StorageManager
    @EnvironmentObject var settingsManager: SettingsManager

    @State private var searchQuery = ""
    @State private var selectedApp: String?
    @State private var selectedNotification: NotificationItem?
    @State private var showingExportOptions = false
    @State private var showingDeleteConfirmation = false
    @FocusState private var isSearchFocused: Bool

    // メモリ上でフィルタリング（高速）
    private var filteredNotifications: [NotificationItem] {
        var notifications = storageManager.notifications

        // アプリフィルタ
        if let app = selectedApp {
            notifications = notifications.filter { $0.appIdentifier == app }
        }

        // 検索フィルタ
        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            notifications = notifications.filter {
                $0.title.lowercased().contains(query) ||
                $0.body.lowercased().contains(query) ||
                $0.appName.lowercased().contains(query)
            }
        }

        return notifications
    }

    private var groupedNotifications: [(date: String, notifications: [NotificationItem])] {
        return groupByDate(filteredNotifications)
    }

    var body: some View {
        HSplitView {
            // 左サイドバー
            sidebarView
                .frame(minWidth: 180, maxWidth: 220)

            // メインコンテンツ
            mainContentView
        }
        .frame(minWidth: 600, minHeight: 400)
        .alert("全ての履歴を削除", isPresented: $showingDeleteConfirmation) {
            Button("キャンセル", role: .cancel) {}
            Button("削除", role: .destructive) {
                try? storageManager.deleteAll()
            }
        } message: {
            Text("すべての通知履歴を削除します。この操作は取り消せません。")
        }
        .onAppear {
            setupKeyboardShortcuts()
        }
    }

    // MARK: - Sidebar

    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 検索
            SearchBar(text: $searchQuery, focused: $isSearchFocused)
                .padding(12)

            Divider()

            // アプリフィルタ
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    Text("アプリ")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)

                    // 全て
                    sidebarItem(
                        name: "すべて",
                        icon: "tray.full.fill",
                        bundleIdentifier: nil,
                        count: storageManager.notifications.count,
                        isSelected: selectedApp == nil,
                        action: { selectedApp = nil }
                    )

                    // アプリ別
                    ForEach(storageManager.fetchApps(), id: \.identifier) { app in
                        sidebarItem(
                            name: app.name,
                            icon: "app.fill",
                            bundleIdentifier: app.identifier,
                            count: app.count,
                            isSelected: selectedApp == app.identifier,
                            action: { selectedApp = app.identifier }
                        )
                    }
                }
                .padding(.bottom, 12)
            }

            Divider()

            // ストレージ情報
            VStack(alignment: .leading, spacing: 4) {
                Text("保存件数: \(storageManager.storageInfo.count) 件")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("ストレージ: \(storageManager.storageInfo.sizeString)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func sidebarItem(
        name: String,
        icon: String,
        bundleIdentifier: String?,
        count: Int,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                // アプリアイコン or SF Symbol
                if let bundleId = bundleIdentifier {
                    AppIconView(bundleIdentifier: bundleId, size: 20)
                } else {
                    Image(systemName: icon)
                        .frame(width: 20, height: 20)
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                }

                Text(name)
                    .lineLimit(1)

                Spacer()

                Text("\(count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }

    // MARK: - Main Content

    private var mainContentView: some View {
        VStack(spacing: 0) {
            // ツールバー
            toolbarView

            Divider()

            // 通知一覧
            if groupedNotifications.isEmpty {
                emptyView
            } else {
                notificationListView
            }
        }
    }

    private var toolbarView: some View {
        HStack {
            // 検索結果情報
            if !searchQuery.isEmpty {
                Text("「\(searchQuery)」の検索結果")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // アクション
            Button(action: { try? storageManager.markAllAsRead() }) {
                Label("すべて既読", systemImage: "checkmark.circle")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button(action: { showingDeleteConfirmation = true }) {
                Label("全削除", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Menu {
                Button("JSON形式") { exportJSON() }
                Button("CSV形式") { exportCSV() }
            } label: {
                Label("エクスポート", systemImage: "square.and.arrow.up")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 120)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("通知がありません")
                .font(.headline)
                .foregroundColor(.secondary)

            if !searchQuery.isEmpty {
                Text("検索条件を変更してみてください")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var notificationListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(groupedNotifications, id: \.date) { group in
                    // 日付ヘッダー
                    Text(group.date)
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 8)

                    // 通知カード
                    ForEach(group.notifications) { notification in
                        NotificationCard(
                            notification: notification,
                            searchQuery: searchQuery,
                            onTap: { handleNotificationTap(notification) },
                            onMarkRead: { try? storageManager.markAsRead(notification.id) },
                            onDelete: { try? storageManager.delete(notification.id) },
                            onOpenApp: { openApp(notification) }
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding(.bottom, 16)
        }
    }

    // MARK: - Actions

    private func handleNotificationTap(_ notification: NotificationItem) {
        try? storageManager.markAsRead(notification.id)
    }

    private func openApp(_ notification: NotificationItem) {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: notification.appIdentifier) {
            NSWorkspace.shared.open(url)
        }
    }

    private func exportJSON() {
        guard let data = storageManager.exportAsJSON() else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "notifications.json"

        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url)
        }
    }

    private func exportCSV() {
        let csv = storageManager.exportAsCSV()

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "notifications.csv"

        if panel.runModal() == .OK, let url = panel.url {
            try? csv.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Helper

    private func groupByDate(_ notifications: [NotificationItem]) -> [(date: String, notifications: [NotificationItem])] {
        let calendar = Calendar.current
        var groups: [String: (date: Date, notifications: [NotificationItem])] = [:]

        for notification in notifications {
            let key: String
            let groupDate: Date

            if calendar.isDateInToday(notification.timestamp) {
                key = "今日"
                groupDate = calendar.startOfDay(for: Date())
            } else if calendar.isDateInYesterday(notification.timestamp) {
                key = "昨日"
                groupDate = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))!
            } else {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "ja_JP")
                formatter.dateFormat = "M月d日（E）"
                key = formatter.string(from: notification.timestamp)
                groupDate = calendar.startOfDay(for: notification.timestamp)
            }

            if groups[key] == nil {
                groups[key] = (date: groupDate, notifications: [])
            }
            groups[key]?.notifications.append(notification)
        }

        // Dateでソート（新しい順）
        let sortedKeys = groups.keys.sorted { key1, key2 in
            let date1 = groups[key1]!.date
            let date2 = groups[key2]!.date
            return date1 > date2
        }

        return sortedKeys.map { (date: $0, notifications: groups[$0]!.notifications) }
    }

    // MARK: - Keyboard Shortcuts

    private func setupKeyboardShortcuts() {
        // 検索フィールドにフォーカスするショートカット（設定から取得）
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            let shortcut = settingsManager.shortcutFocusSearch

            // ショートカットが設定されていて、イベントと一致するか確認
            if !shortcut.isDisabled && shortcut.matches(event: event) {
                isSearchFocused = true
                return nil  // イベントを消費
            }

            return event
        }
    }
}

// MARK: - Notification Card

struct NotificationCard: View {
    let notification: NotificationItem
    let searchQuery: String
    let onTap: () -> Void
    let onMarkRead: () -> Void
    let onDelete: () -> Void
    let onOpenApp: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // アプリアイコン
            AppIconView(bundleIdentifier: notification.appIdentifier, size: 36)

            // コンテンツ
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(notification.appName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(notification.dateTimeString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(notification.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(2)

                Text(notification.body)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }

            // 未読インジケーター
            if !notification.isRead {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isHovering ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture(perform: onTap)
        .contextMenu {
            Button(action: onOpenApp) {
                Label("アプリを開く", systemImage: "arrow.up.forward.app")
            }

            Button(action: onMarkRead) {
                Label("既読にする", systemImage: "checkmark.circle")
            }

            Divider()

            Button(role: .destructive, action: onDelete) {
                Label("削除", systemImage: "trash")
            }
        }
    }
}

#Preview {
    HistoryWindowView()
        .environmentObject(StorageManager.shared)
        .environmentObject(SettingsManager.shared)
        .frame(width: 700, height: 600)
}
