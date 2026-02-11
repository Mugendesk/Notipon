import Foundation
import AppKit
import Combine
import SQLite3

/// macOS通知監視（アダプティブポーリング + SQLite）
final class NotificationMonitor: ObservableObject {
    static let shared = NotificationMonitor()

    private var storageManager: StorageManager { StorageManager.shared }
    private var settingsManager: SettingsManager { SettingsManager.shared }
    private var notificationCleaner: NotificationCleaner { NotificationCleaner.shared }
    private var popupController: NotificationPopupController { NotificationPopupController.shared }

    @Published private(set) var isMonitoring = false
    @Published private(set) var lastError: String?
    @Published private(set) var dbStatus: DBStatus = .unknown

    private var knownNotificationIds = Set<String>()
    private var pollingTimer: Timer?

    // MARK: - アダプティブポーリング設定
    private enum PollingState {
        case idle       // 通知なし: 長間隔
        case active     // 通知検知/AXイベント: 短間隔
        case cooldown   // アクティブ→アイドルへの遷移中
    }

    private static let idleInterval: TimeInterval = 2.0
    private static let activeInterval: TimeInterval = 0.1
    private static let cooldownIntervals: [TimeInterval] = [0.3, 0.5, 1.0, 2.0]

    private var pollingState: PollingState = .idle
    private var cooldownStep = 0
    private var activePollCount = 0
    private static let maxActivePollCount = 50  // アクティブ状態の最大回数（5秒）
    private static let knownIdsMaxCount = 5000  // knownNotificationIdsの上限

    enum DBStatus {
        case unknown
        case notFound
        case noPermission
        case ready
        case error(String)

        var description: String {
            switch self {
            case .unknown: return "確認中..."
            case .notFound: return "通知DBが見つかりません"
            case .noPermission: return "フルディスクアクセスが必要です"
            case .ready: return "準備完了"
            case .error(let msg): return "エラー: \(msg)"
            }
        }
    }

    private init() {
        // 起動時にDB状態を確認
        checkDBStatus()
    }

    /// DB状態を確認
    private func checkDBStatus() {
        let dbPath = PermissionManager.notificationDBPath

        if !FileManager.default.fileExists(atPath: dbPath) {
            dbStatus = .notFound
            NSLog("NotificationMonitor: DB not found at %@", dbPath)
            return
        }

        if !FileManager.default.isReadableFile(atPath: dbPath) {
            dbStatus = .noPermission
            NSLog("NotificationMonitor: No permission to read %@", dbPath)
            return
        }

        // スキーマを確認してログ出力
        let schema = PermissionManager.getDBSchema()
        NSLog("NotificationMonitor: DB Schema:")
        for (table, columns) in schema {
            NSLog("  %@: %@", table, columns.joined(separator: ", "))
        }

        dbStatus = .ready
    }

    // MARK: - Monitoring Control

    /// 監視を開始
    func startMonitoring() {
        guard !isMonitoring else { return }

        // 権限チェック
        guard PermissionManager.shared.hasFullDiskAccess() else {
            lastError = "フルディスクアクセス権限がありません"
            return
        }

        // 初回読み込み
        readExistingNotifications()

        // アイドル間隔でポーリング開始
        schedulePolling(interval: Self.idleInterval)
        pollingState = .idle

        isMonitoring = true
        lastError = nil

        NSLog("NotificationMonitor: Started monitoring (adaptive: idle=%.1fs, active=%.1fs)",
              Self.idleInterval, Self.activeInterval)
    }

    /// 外部からアクティブ状態に切り替え（AXObserverイベント等）
    func triggerActivePolling() {
        guard isMonitoring else { return }
        transitionToActive()
    }

    private func transitionToActive() {
        guard pollingState != .active else { return }
        pollingState = .active
        activePollCount = 0
        schedulePolling(interval: Self.activeInterval)
        NSLog("NotificationMonitor: → active polling")
    }

    private func transitionToCooldown() {
        pollingState = .cooldown
        cooldownStep = 0
        let interval = Self.cooldownIntervals[0]
        schedulePolling(interval: interval)
        NSLog("NotificationMonitor: → cooldown (%.1fs)", interval)
    }

    private func transitionToIdle() {
        pollingState = .idle
        schedulePolling(interval: Self.idleInterval)
        NSLog("NotificationMonitor: → idle polling")
    }

    private func schedulePolling(interval: TimeInterval) {
        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.checkForNewNotifications()
        }
    }

    /// ポーリングチェック（アダプティブ・軽量IDチェック）
    private func checkForNewNotifications() {
        // Step 1: IDだけ取得して差分チェック（BLOBを読まない軽量クエリ）
        let newIds = fetchNewNotificationIds()

        if !newIds.isEmpty {
            // 先にIDを登録（空title/bodyレコードでも再スキャンを防ぐ）
            for id in newIds {
                knownNotificationIds.insert(id)
            }
            trimKnownIdsIfNeeded()

            // Step 2: 新ID数+バッファ分だけ読み込み（500件全部ではなく最小限）
            let newIdSet = Set(newIds)
            let recentNotifications = readNotificationsFromDB(limit: newIds.count + 5)
            let newNotifications = recentNotifications.filter { newIdSet.contains($0.id) }

            if !newNotifications.isEmpty {
                NSLog("NotificationMonitor: Found %d new", newNotifications.count)

                // ポップアップ表示
                if let latest = newNotifications.first {
                    popupController.show(latest)
                }

                // DB保存
                let notificationsToSave = newNotifications
                DispatchQueue.global(qos: .utility).async { [weak self] in
                    guard let self = self else { return }
                    try? self.storageManager.saveAll(notificationsToSave)

                    if self.settingsManager.autoDeleteFromNotificationCenter {
                        let delay = self.settingsManager.deleteDelay.rawValue
                        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(delay)) {
                            self.notificationCleaner.clearNotificationCenter()
                        }
                    }
                }
            }

            // 通知検知したらアクティブを延長
            if pollingState != .active {
                transitionToActive()
            }
            activePollCount = 0
            return
        }

        // 新規通知なし → 状態遷移
        switch pollingState {
        case .active:
            activePollCount += 1
            if activePollCount >= Self.maxActivePollCount {
                transitionToCooldown()
            }
        case .cooldown:
            cooldownStep += 1
            if cooldownStep < Self.cooldownIntervals.count {
                let interval = Self.cooldownIntervals[cooldownStep]
                schedulePolling(interval: interval)
            } else {
                transitionToIdle()
            }
        case .idle:
            break
        }
    }

    /// knownNotificationIdsが肥大化しないよう古いものを削除
    private func trimKnownIdsIfNeeded() {
        if knownNotificationIds.count > Self.knownIdsMaxCount {
            // 半分に削減（古い順の保証はないが、サイズ制御が目的）
            let removeCount = knownNotificationIds.count - Self.knownIdsMaxCount / 2
            for _ in 0..<removeCount {
                knownNotificationIds.removeFirst()
            }
            NSLog("NotificationMonitor: Trimmed knownIds to %d", knownNotificationIds.count)
        }
    }

    /// 監視を停止
    func stopMonitoring() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        isMonitoring = false
        NSLog("NotificationMonitor: Stopped monitoring")
    }

    // MARK: - DB Reading

    /// 既存の通知を読み込み
    private func readExistingNotifications() {
        // 全UUIDを取得（空title/bodyのレコードも含む）→ ポーリングで再検知されないように
        let allIds = fetchAllNotificationIds()
        knownNotificationIds = Set(allIds)

        // フルデータを読み込んでローカルDBに保存
        let notifications = readNotificationsFromDB()
        try? storageManager.saveAll(notifications)
    }

    /// 新しい通知のみ読み込み（refresh用）
    private func readNewNotifications() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            let allNotifications = self.readNotificationsFromDB()
            let newNotifications = allNotifications.filter { !self.knownNotificationIds.contains($0.id) }

            guard !newNotifications.isEmpty else { return }

            // メインスレッドで状態更新とUI処理
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                for notification in newNotifications {
                    self.knownNotificationIds.insert(notification.id)
                }

                try? self.storageManager.saveAll(newNotifications)

                if let latest = newNotifications.first {
                    self.popupController.show(latest)
                }

                if self.settingsManager.autoDeleteFromNotificationCenter {
                    let delay = self.settingsManager.deleteDelay.rawValue
                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(delay)) {
                        self.notificationCleaner.clearNotificationCenter()
                    }
                }

                NSLog("NotificationMonitor: %d new notifications (refresh)", newNotifications.count)
            }
        }
    }

    // MARK: - 軽量IDチェック（ポーリング用）

    /// 全UUIDを取得（knownIds初期化用）
    private func fetchAllNotificationIds() -> [String] {
        return fetchNotificationIds(onlyNew: false)
    }

    /// 新しいUUIDだけ取得（ポーリング用）
    private func fetchNewNotificationIds() -> [String] {
        return fetchNotificationIds(onlyNew: true)
    }

    /// IDだけ取得（BLOBを読まないので軽量）
    private func fetchNotificationIds(onlyNew: Bool) -> [String] {
        let dbPath = PermissionManager.notificationDBPath

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_close(db) }

        let query = """
            SELECT uuid FROM record
            WHERE data IS NOT NULL
            ORDER BY delivered_date DESC
            LIMIT 500
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        var ids: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let recId = extractUUID(statement: statement, columnIndex: 0)
            if onlyNew {
                if !knownNotificationIds.contains(recId) {
                    ids.append(recId)
                }
            } else {
                ids.append(recId)
            }
        }
        return ids
    }

    /// UUIDカラムからString IDを抽出
    private func extractUUID(statement: OpaquePointer?, columnIndex: Int32) -> String {
        if let uuidPtr = sqlite3_column_text(statement, columnIndex) {
            return String(cString: uuidPtr)
        } else if let blobPtr = sqlite3_column_blob(statement, columnIndex) {
            let blobSize = sqlite3_column_bytes(statement, columnIndex)
            let data = Data(bytes: blobPtr, count: Int(blobSize))
            return data.map { String(format: "%02x", $0) }.joined()
        }
        return UUID().uuidString
    }

    // MARK: - フルデータ読み込み

    /// 通知DBから全件読み取り（初回読み込み用）
    private func readNotificationsFromDB() -> [NotificationItem] {
        return readNotificationsFromDB(limit: 500)
    }

    /// 通知DBから読み取り（件数指定）
    private func readNotificationsFromDB(limit: Int) -> [NotificationItem] {
        let dbPath = PermissionManager.notificationDBPath

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            updateStatusOnMain(error: "通知DBを開けません")
            return []
        }
        defer { sqlite3_close(db) }

        let query = """
            SELECT
                r.uuid,
                r.app_id,
                a.identifier,
                r.data,
                r.delivered_date
            FROM record r
            LEFT JOIN app a ON r.app_id = a.app_id
            WHERE r.data IS NOT NULL
            ORDER BY r.delivered_date DESC
            LIMIT \(limit)
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            let error = String(cString: sqlite3_errmsg(db))
            updateStatusOnMain(error: error)
            return []
        }
        defer { sqlite3_finalize(statement) }

        return parseNotificationRows(statement: statement)
    }

    /// SQLite結果をNotificationItemに変換（共通処理）
    private func parseNotificationRows(statement: OpaquePointer?) -> [NotificationItem] {
        var notifications: [NotificationItem] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            let recId = extractUUID(statement: statement, columnIndex: 0)
            let appId = sqlite3_column_int64(statement, 1)

            let appIdentifier: String
            if let identifierPtr = sqlite3_column_text(statement, 2) {
                appIdentifier = String(cString: identifierPtr)
            } else {
                appIdentifier = "unknown.\(appId)"
            }

            var title = ""
            var subtitle: String? = nil
            var body = ""
            var imageData: Data? = nil

            if let blobData = extractBlobData(statement: statement, columnIndex: 3) {
                title = blobData.title
                subtitle = blobData.subtitle
                body = blobData.body
                imageData = blobData.imageData
            }

            let cfTimestamp = sqlite3_column_double(statement, 4)
            let timestamp = Date(timeIntervalSinceReferenceDate: cfTimestamp)

            if title.isEmpty && body.isEmpty {
                continue
            }

            let appName = getAppName(for: appIdentifier)

            let notification = NotificationItem(
                id: recId,
                appIdentifier: appIdentifier,
                appName: appName,
                title: title,
                body: body,
                subtitle: subtitle,
                timestamp: timestamp,
                imageData: imageData
            )

            notifications.append(notification)
        }

        return notifications
    }

    /// @Published プロパティをメインスレッドで安全に更新
    private func updateStatusOnMain(error: String) {
        if Thread.isMainThread {
            lastError = error
            dbStatus = .error(error)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.lastError = error
                self?.dbStatus = .error(error)
            }
        }
    }

    /// recordテーブルのカラム一覧を取得
    private func getRecordColumns(db: OpaquePointer?) -> [String] {
        var columns: [String] = []
        let query = "PRAGMA table_info(record)"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return columns
        }
        defer { sqlite3_finalize(statement) }

        while sqlite3_step(statement) == SQLITE_ROW {
            if let colName = sqlite3_column_text(statement, 1) {
                columns.append(String(cString: colName))
            }
        }
        return columns
    }

    /// BLOBデータからtitle/subtitle/body/imageを抽出
    private struct BlobContent {
        var title: String = ""
        var subtitle: String? = nil
        var body: String = ""
        var imageData: Data? = nil
    }

    private func extractBlobData(statement: OpaquePointer?, columnIndex: Int32) -> BlobContent? {
        guard let blobPtr = sqlite3_column_blob(statement, columnIndex) else { return nil }
        let blobSize = sqlite3_column_bytes(statement, columnIndex)
        guard blobSize > 0 else { return nil }

        let data = Data(bytes: blobPtr, count: Int(blobSize))

        // 方法1: bplist形式（NSKeyedArchiver）
        if data.prefix(6).elementsEqual("bplist".utf8) {
            do {
                // NSKeyedUnarchiverで複数のクラスを許可
                let allowedClasses: [AnyClass] = [
                    NSDictionary.self, NSArray.self, NSString.self,
                    NSNumber.self, NSData.self, NSDate.self,
                    NSURL.self, NSNull.self
                ]

                if let unarchived = try NSKeyedUnarchiver.unarchivedObject(ofClasses: allowedClasses, from: data) {
                    return extractFromObject(unarchived)
                }
            } catch {
                // フォールバック: 古い方式
                if let unarchived = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) {
                    return extractFromObject(unarchived)
                }
            }
        }

        // 方法2: XML plist形式
        do {
            if let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
                return extractFromDictionary(plist)
            }
        } catch {
            // 無視
        }

        // 方法3: 生データからキーを探す
        if let content = extractFromRawData(data) {
            return content
        }

        return nil
    }

    private func extractFromObject(_ obj: Any) -> BlobContent? {
        if let dict = obj as? [String: Any] {
            return extractFromDictionary(dict)
        } else if let dict = obj as? NSDictionary as? [String: Any] {
            return extractFromDictionary(dict)
        }
        return nil
    }

    private func extractFromDictionary(_ dict: [String: Any]) -> BlobContent {
        var content = BlobContent()

        // 様々なキー名を試す
        let titleKeys = ["titl", "title", "Title", "alertTitle", "header"]
        let subtitleKeys = ["subt", "subtitle", "Subtitle", "alertSubtitle"]
        let bodyKeys = ["body", "Body", "alertBody", "message", "text", "content"]
        let imageKeys = ["atta", "attachments", "attachment", "imag", "image", "icon", "thumbnail", "artwork", "albumArt", "contentImage"]

        for key in titleKeys {
            if let value = dict[key] as? String, !value.isEmpty {
                content.title = value
                break
            }
        }

        for key in subtitleKeys {
            if let value = dict[key] as? String, !value.isEmpty {
                content.subtitle = value
                break
            }
        }

        for key in bodyKeys {
            if let value = dict[key] as? String, !value.isEmpty {
                content.body = value
                break
            }
        }

        // 画像データを探す
        for key in imageKeys {
            if let imageData = dict[key] as? Data, imageData.count > 100 {
                content.imageData = imageData
                break
            }
            // ネストされた場合（attachments配列など）
            if let attachments = dict[key] as? [[String: Any]], let first = attachments.first {
                if let data = first["data"] as? Data ?? first["imageData"] as? Data {
                    content.imageData = data
                    break
                }
            }
        }

        // 全キーをスキャンして画像データを探す（上記で見つからない場合）
        if content.imageData == nil {
            for (_, value) in dict {
                if let data = value as? Data, data.count > 1000 {
                    // PNG/JPEGヘッダーをチェック
                    let header = data.prefix(8)
                    if header.starts(with: [0x89, 0x50, 0x4E, 0x47]) ||  // PNG
                       header.starts(with: [0xFF, 0xD8, 0xFF]) {         // JPEG
                        content.imageData = data
                        break
                    }
                }
            }
        }

        // ネストされた構造を探す
        if content.title.isEmpty || content.imageData == nil {
            for (_, value) in dict {
                if let nested = value as? [String: Any] {
                    let nestedContent = extractFromDictionary(nested)
                    if content.title.isEmpty && !nestedContent.title.isEmpty {
                        content.title = nestedContent.title
                        content.subtitle = nestedContent.subtitle
                        content.body = nestedContent.body
                    }
                    if content.imageData == nil && nestedContent.imageData != nil {
                        content.imageData = nestedContent.imageData
                    }
                }
            }
        }

        return content
    }

    private func extractFromRawData(_ data: Data) -> BlobContent? {
        // 文字列として解析を試みる
        guard let str = String(data: data, encoding: .utf8) else { return nil }

        // JSON形式を試す
        if str.contains("{") {
            if let jsonData = str.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                return extractFromDictionary(json)
            }
        }

        return nil
    }

    /// バンドルIDからアプリ名を取得
    private func getAppName(for bundleId: String) -> String {
        if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
           let bundle = Bundle(url: appUrl),
           let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String {
            return name
        }

        // バンドルIDからアプリ名を推測
        let components = bundleId.split(separator: ".")
        if let lastName = components.last {
            return String(lastName)
        }

        return bundleId
    }

    // MARK: - Manual Refresh

    /// 手動で再読み込み
    func refresh() {
        readNewNotifications()
    }

    /// 全てリセットして再読み込み
    func reset() {
        knownNotificationIds.removeAll()
        readExistingNotifications()
    }
}
