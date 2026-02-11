import Foundation
import AppKit
import SQLite3

/// 権限管理
final class PermissionManager {
    static let shared = PermissionManager()

    private init() {}

    // MARK: - Notification DB Path

    /// 検索対象のDBパス候補（優先順）
    private static var dbPathCandidates: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            // macOS 15+ (Sequoia, Tahoe)
            "\(home)/Library/Group Containers/group.com.apple.usernoted/db2/db",
            // 他の可能性
            "\(home)/Library/Group Containers/group.com.apple.usernoted/db3/db",
            "\(home)/Library/Group Containers/group.com.apple.usernoted/db/db",
            // 古いmacOS
            "/private/var/folders/*/T/com.apple.notificationcenterui/db/db"
        ]
    }

    /// 見つかった通知DBのパス（キャッシュ）
    private static var _cachedDBPath: String?

    /// macOS 通知DBのパス（動的に検索）
    static var notificationDBPath: String {
        // キャッシュがあれば返す
        if let cached = _cachedDBPath, FileManager.default.fileExists(atPath: cached) {
            return cached
        }

        // パス候補を順にチェック
        for path in dbPathCandidates {
            // ワイルドカードを含むパスは展開
            if path.contains("*") {
                if let expanded = expandWildcardPath(path), isValidNotificationDB(at: expanded) {
                    _cachedDBPath = expanded
                    return expanded
                }
            } else if isValidNotificationDB(at: path) {
                _cachedDBPath = path
                return path
            }
        }

        // デフォルト（見つからない場合）
        return dbPathCandidates[0]
    }

    /// ワイルドカードパスを展開
    private static func expandWildcardPath(_ pattern: String) -> String? {
        let components = pattern.components(separatedBy: "*")
        guard components.count == 2 else { return nil }

        let baseDir = components[0]
        let suffix = components[1]

        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: String(baseDir.dropLast())) else {
            return nil
        }

        for item in contents {
            let fullPath = baseDir.dropLast().appending(item).appending(suffix)
            if FileManager.default.fileExists(atPath: fullPath) {
                return fullPath
            }
        }
        return nil
    }

    /// 通知DBとして有効かチェック（recordテーブルが存在するか）
    private static func isValidNotificationDB(at path: String) -> Bool {
        guard FileManager.default.isReadableFile(atPath: path) else { return false }

        var db: OpaquePointer?
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            return false
        }
        defer { sqlite3_close(db) }

        // recordテーブルが存在するか確認
        let query = "SELECT name FROM sqlite_master WHERE type='table' AND name='record'"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return false
        }
        defer { sqlite3_finalize(statement) }

        return sqlite3_step(statement) == SQLITE_ROW
    }

    /// 通知DBのスキーマを取得（デバッグ用）
    static func getDBSchema() -> [String: [String]] {
        var schema: [String: [String]] = [:]
        let path = notificationDBPath

        var db: OpaquePointer?
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            return schema
        }
        defer { sqlite3_close(db) }

        // テーブル一覧
        let tablesQuery = "SELECT name FROM sqlite_master WHERE type='table'"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, tablesQuery, -1, &statement, nil) == SQLITE_OK else {
            return schema
        }
        defer { sqlite3_finalize(statement) }

        var tables: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let name = sqlite3_column_text(statement, 0) {
                tables.append(String(cString: name))
            }
        }

        // 各テーブルのカラム
        for table in tables {
            var columns: [String] = []
            let pragmaQuery = "PRAGMA table_info(\(table))"
            var pragmaStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, pragmaQuery, -1, &pragmaStmt, nil) == SQLITE_OK {
                while sqlite3_step(pragmaStmt) == SQLITE_ROW {
                    if let colName = sqlite3_column_text(pragmaStmt, 1) {
                        columns.append(String(cString: colName))
                    }
                }
                sqlite3_finalize(pragmaStmt)
            }
            schema[table] = columns
        }

        return schema
    }

    // MARK: - Permission Checks

    /// フルディスクアクセス権限があるか確認
    func hasFullDiskAccess() -> Bool {
        let path = Self.notificationDBPath
        return FileManager.default.isReadableFile(atPath: path)
    }

    /// 通知DBが存在するか確認
    func notificationDBExists() -> Bool {
        FileManager.default.fileExists(atPath: Self.notificationDBPath)
    }

    /// アクセシビリティ権限があるか確認
    func hasAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    /// 全ての必要な権限があるか
    func hasAllRequiredPermissions() -> Bool {
        hasFullDiskAccess()
    }

    // MARK: - Permission Requests

    /// システム環境設定のセキュリティとプライバシーを開く
    func openSecurityPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }

    /// アクセシビリティ設定を開く
    func openAccessibilityPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// 権限リクエストアラートを表示
    func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "フルディスクアクセスが必要です"
        alert.informativeText = """
        NotifyDeckが通知履歴を読み取るには、フルディスクアクセス権限が必要です。

        システム設定 > プライバシーとセキュリティ > フルディスクアクセス から NotifyDeck を追加してください。
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "設定を開く")
        alert.addButton(withTitle: "後で")

        if alert.runModal() == .alertFirstButtonReturn {
            openSecurityPreferences()
        }
    }

    // MARK: - Permission Status

    enum PermissionStatus {
        case granted
        case denied
        case notDetermined

        var description: String {
            switch self {
            case .granted: return "許可済み"
            case .denied: return "拒否"
            case .notDetermined: return "未設定"
            }
        }
    }

    /// 現在の権限状態
    var fullDiskAccessStatus: PermissionStatus {
        if hasFullDiskAccess() {
            return .granted
        } else if notificationDBExists() {
            return .denied
        } else {
            return .notDetermined
        }
    }
}
