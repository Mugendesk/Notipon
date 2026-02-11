import Foundation
import GRDB
import Combine

/// ローカルストレージ管理（GRDB）
final class StorageManager: ObservableObject {
    static let shared = StorageManager()

    private var dbQueue: DatabaseQueue?
    private let settingsManager = SettingsManager.shared

    @Published private(set) var notifications: [NotificationItem] = []
    @Published private(set) var unreadCount: Int = 0
    @Published private(set) var storageInfo: StorageInfo = StorageInfo()

    struct StorageInfo {
        var count: Int = 0
        var sizeBytes: Int64 = 0

        var sizeString: String {
            ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
        }
    }

    private init() {
        setupDatabase()
    }

    // MARK: - Database Setup

    private var databasePath: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("NotifyDeck")

        if !FileManager.default.fileExists(atPath: appFolder.path) {
            try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        }

        return appFolder.appendingPathComponent("notifications.db")
    }

    private func setupDatabase() {
        do {
            dbQueue = try DatabaseQueue(path: databasePath.path)

            try dbQueue?.write { db in
                try db.create(table: "notifications", ifNotExists: true) { t in
                    t.column("id", .text).primaryKey()
                    t.column("app_identifier", .text).notNull()
                    t.column("app_name", .text).notNull()
                    t.column("title", .text).notNull()
                    t.column("body", .text).notNull()
                    t.column("subtitle", .text)
                    t.column("timestamp", .datetime).notNull()
                    t.column("is_read", .boolean).notNull().defaults(to: false)
                    t.column("thread_identifier", .text)
                    t.column("category_identifier", .text)
                    t.column("image_data", .blob)
                }

                // マイグレーション: image_dataカラムを追加
                if try db.columns(in: "notifications").first(where: { $0.name == "image_data" }) == nil {
                    try db.alter(table: "notifications") { t in
                        t.add(column: "image_data", .blob)
                    }
                }

                // インデックス作成
                try db.create(
                    index: "idx_notifications_timestamp",
                    on: "notifications",
                    columns: ["timestamp"],
                    ifNotExists: true
                )
                try db.create(
                    index: "idx_notifications_app",
                    on: "notifications",
                    columns: ["app_identifier"],
                    ifNotExists: true
                )
            }

            refreshNotifications()
            updateStorageInfo()
        } catch {
            print("Database setup error: \(error)")
        }
    }

    // MARK: - CRUD Operations

    /// 通知を保存
    func save(_ notification: NotificationItem) throws {
        // 除外アプリチェック
        guard !settingsManager.isAppExcluded(notification.appIdentifier) else { return }

        try dbQueue?.write { db in
            try notification.save(db)
        }
        refreshNotifications()
    }

    /// 複数の通知を一括保存
    func saveAll(_ notifications: [NotificationItem]) throws {
        let filtered = notifications.filter { !settingsManager.isAppExcluded($0.appIdentifier) }

        try dbQueue?.write { db in
            for notification in filtered {
                try notification.save(db)
            }
        }
        refreshNotifications()
    }

    /// 通知を既読にする
    func markAsRead(_ id: String) throws {
        try dbQueue?.write { db in
            try db.execute(
                sql: "UPDATE notifications SET is_read = 1 WHERE id = ?",
                arguments: [id]
            )
        }
        refreshNotifications()
    }

    /// 全て既読にする
    func markAllAsRead() throws {
        try dbQueue?.write { db in
            try db.execute(sql: "UPDATE notifications SET is_read = 1")
        }
        refreshNotifications()
    }

    /// 通知を削除
    func delete(_ id: String) throws {
        try dbQueue?.write { db in
            try db.execute(
                sql: "DELETE FROM notifications WHERE id = ?",
                arguments: [id]
            )
        }
        refreshNotifications()
    }

    /// 古い通知を削除
    func deleteOldNotifications() throws {
        guard let days = settingsManager.retentionPeriod.days else { return }

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!

        try dbQueue?.write { db in
            try db.execute(
                sql: "DELETE FROM notifications WHERE timestamp < ?",
                arguments: [cutoffDate]
            )
            // データベースファイルを最適化・圧縮
            try db.execute(sql: "VACUUM")
        }
        refreshNotifications()
        updateStorageInfo()
    }

    /// 全ての通知を削除
    func deleteAll() throws {
        try dbQueue?.write { db in
            try db.execute(sql: "DELETE FROM notifications")
            // データベースファイルを最適化・圧縮
            try db.execute(sql: "VACUUM")
        }
        refreshNotifications()
        updateStorageInfo()
    }

    // MARK: - Fetch Operations

    /// 通知一覧を更新（画像データを除外して軽量に取得）
    func refreshNotifications() {
        do {
            notifications = try dbQueue?.read { db in
                let columns: [NotificationItem.Columns] = [
                    .id, .appIdentifier, .appName, .title, .body,
                    .subtitle, .timestamp, .isRead, .threadIdentifier, .categoryIdentifier
                ]
                return try NotificationItem
                    .select(columns)
                    .order(NotificationItem.Columns.timestamp.desc)
                    .fetchAll(db)
            } ?? []

            unreadCount = notifications.filter { !$0.isRead }.count
            updateStorageInfo()
        } catch {
            print("Fetch error: \(error)")
        }
    }

    /// 指定IDの通知の画像データを取得
    func fetchImageData(for id: String) -> Data? {
        try? dbQueue?.read { db in
            try Data.fetchOne(
                db,
                sql: "SELECT image_data FROM notifications WHERE id = ?",
                arguments: [id]
            )
        }
    }

    /// フィルタを適用して取得（画像データ除外）
    func fetch(filter: NotificationFilter) -> [NotificationItem] {
        do {
            return try dbQueue?.read { db in
                let columns: [NotificationItem.Columns] = [
                    .id, .appIdentifier, .appName, .title, .body,
                    .subtitle, .timestamp, .isRead, .threadIdentifier, .categoryIdentifier
                ]
                var query = NotificationItem.select(columns)

                // アプリフィルタ
                if let apps = filter.appIdentifiers, !apps.isEmpty {
                    query = query.filter(apps.contains(NotificationItem.Columns.appIdentifier))
                }

                // 既読/未読フィルタ
                if let isRead = filter.isReadFilter {
                    query = query.filter(NotificationItem.Columns.isRead == isRead)
                }

                // 日付範囲
                if let range = filter.dateRange {
                    query = query.filter(
                        NotificationItem.Columns.timestamp >= range.lowerBound &&
                        NotificationItem.Columns.timestamp <= range.upperBound
                    )
                }

                var results = try query
                    .order(NotificationItem.Columns.timestamp.desc)
                    .fetchAll(db)

                // 検索クエリ（メモリ内フィルタ）
                if let searchQuery = filter.searchQuery, !searchQuery.isEmpty {
                    let lowercased = searchQuery.lowercased()
                    results = results.filter {
                        $0.title.lowercased().contains(lowercased) ||
                        $0.body.lowercased().contains(lowercased) ||
                        $0.appName.lowercased().contains(lowercased)
                    }
                }

                return results
            } ?? []
        } catch {
            print("Filter fetch error: \(error)")
            return []
        }
    }

    /// 直近N件を取得
    func fetchRecent(count: Int) -> [NotificationItem] {
        Array(notifications.prefix(count))
    }

    /// 未読のみ取得
    func fetchUnread() -> [NotificationItem] {
        notifications.filter { !$0.isRead }
    }

    /// アプリ一覧を取得
    func fetchApps() -> [(identifier: String, name: String, count: Int)] {
        var apps: [String: (name: String, count: Int)] = [:]

        for notification in notifications {
            if let existing = apps[notification.appIdentifier] {
                apps[notification.appIdentifier] = (existing.name, existing.count + 1)
            } else {
                apps[notification.appIdentifier] = (notification.appName, 1)
            }
        }

        return apps.map { (identifier: $0.key, name: $0.value.name, count: $0.value.count) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// 日別にグループ化
    func groupByDate() -> [(date: String, notifications: [NotificationItem])] {
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

    // MARK: - Storage Info

    private func updateStorageInfo() {
        storageInfo.count = notifications.count

        if let attributes = try? FileManager.default.attributesOfItem(atPath: databasePath.path),
           let size = attributes[.size] as? Int64 {
            storageInfo.sizeBytes = size
        }
    }

    // MARK: - Export

    /// JSONとしてエクスポート
    func exportAsJSON() -> Data? {
        try? JSONEncoder().encode(notifications)
    }

    /// CSVとしてエクスポート
    func exportAsCSV() -> String {
        var csv = "ID,App,Title,Body,Timestamp,IsRead\n"

        for n in notifications {
            let row = [
                n.id,
                n.appName,
                n.title.replacingOccurrences(of: ",", with: ";"),
                n.body.replacingOccurrences(of: ",", with: ";").replacingOccurrences(of: "\n", with: " "),
                ISO8601DateFormatter().string(from: n.timestamp),
                n.isRead ? "true" : "false"
            ].joined(separator: ",")
            csv += row + "\n"
        }

        return csv
    }

    // MARK: - Test Data Generation

    /// 負荷テスト用の通知を生成
    /// - Parameter count: 生成する件数
    /// - Throws: データベースエラー
    func generateTestNotifications(count: Int) throws {
        let notifications = (0..<count).map { index -> NotificationItem in
            // ランダムなアプリ選択
            let app = AppConstants.testApps.randomElement()!

            // 過去30日間のランダムなタイムスタンプ
            let daysAgo = Double.random(in: 0...30)
            let secondsAgo = daysAgo * 24 * 60 * 60
            let timestamp = Date().addingTimeInterval(-secondsAgo)

            // 30%の確率で既読
            let isRead = Double.random(in: 0...1) < 0.3

            // ランダムなタイトル・本文
            let title = AppConstants.testTitles.randomElement()!
            let body = AppConstants.testBodies.randomElement()!

            return NotificationItem(
                appIdentifier: app.identifier,
                appName: app.name,
                title: "\(title) #\(index + 1)",
                body: body,
                timestamp: timestamp,
                isRead: isRead
            )
        }

        // バックグラウンドで一括保存
        try dbQueue?.write { db in
            for notification in notifications {
                // 除外アプリチェックをスキップ（テストデータなので）
                try notification.save(db)
            }
        }

        // UI更新
        DispatchQueue.main.async {
            self.refreshNotifications()
        }
    }
}
