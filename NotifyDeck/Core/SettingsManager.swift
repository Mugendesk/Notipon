import Foundation
import Combine
import AppKit

/// 設定管理
final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    private let defaults = UserDefaults.standard

    // MARK: - Keys

    private enum Keys {
        static let launchAtLogin = "launchAtLogin"
        static let showUnreadBadge = "showUnreadBadge"
        static let autoDeleteFromNotificationCenter = "autoDeleteFromNotificationCenter"
        static let deleteDelay = "deleteDelay"
        static let hoverPreviewMode = "hoverPreviewMode"
        static let retentionPeriod = "retentionPeriod"
        static let excludedApps = "excludedApps"
        // ポップアップ設定
        static let popupEnabled = "popupEnabled"
        static let popupX = "popupX"
        static let popupY = "popupY"
        static let popupWidth = "popupWidth"
        static let popupHeight = "popupHeight"
        static let popupOpacity = "popupOpacity"
        static let popupDuration = "popupDuration"
        static let popupFontSize = "popupFontSize"
        // ショートカット設定
        static let shortcutOpenHistory = "shortcutOpenHistory"
        static let shortcutFocusSearch = "shortcutFocusSearch"
        // ホバープレビュー設定
        static let hoverPreviewWidth = "hoverPreviewWidth"
        static let hoverPreviewHeight = "hoverPreviewHeight"
        static let hoverPreviewFontSize = "hoverPreviewFontSize"
        // ドロップダウン設定
        static let dropdownWidth = "dropdownWidth"
        static let dropdownHeight = "dropdownHeight"
        static let dropdownFontSize = "dropdownFontSize"
    }

    // MARK: - Published Properties

    /// ログイン時に起動
    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    /// 未読バッジを表示
    @Published var showUnreadBadge: Bool {
        didSet { defaults.set(showUnreadBadge, forKey: Keys.showUnreadBadge) }
    }

    /// 保存後、通知センターから自動削除
    @Published var autoDeleteFromNotificationCenter: Bool {
        didSet { defaults.set(autoDeleteFromNotificationCenter, forKey: Keys.autoDeleteFromNotificationCenter) }
    }

    /// 削除までの遅延時間（秒）
    @Published var deleteDelay: DeleteDelay {
        didSet { defaults.set(deleteDelay.rawValue, forKey: Keys.deleteDelay) }
    }

    /// ホバープレビューの表示モード
    @Published var hoverPreviewMode: HoverPreviewMode {
        didSet { defaults.set(hoverPreviewMode.rawValue, forKey: Keys.hoverPreviewMode) }
    }

    /// 保存期間
    @Published var retentionPeriod: RetentionPeriod {
        didSet { defaults.set(retentionPeriod.rawValue, forKey: Keys.retentionPeriod) }
    }

    /// 除外アプリのバンドルID一覧
    @Published var excludedApps: [String] {
        didSet { defaults.set(excludedApps, forKey: Keys.excludedApps) }
    }

    // MARK: - Popup Settings

    /// ポップアップ通知を有効にする
    @Published var popupEnabled: Bool {
        didSet { defaults.set(popupEnabled, forKey: Keys.popupEnabled) }
    }

    /// ポップアップX座標
    @Published var popupX: CGFloat {
        didSet { defaults.set(popupX, forKey: Keys.popupX) }
    }

    /// ポップアップY座標
    @Published var popupY: CGFloat {
        didSet { defaults.set(popupY, forKey: Keys.popupY) }
    }

    /// ポップアップ幅
    @Published var popupWidth: CGFloat {
        didSet { defaults.set(popupWidth, forKey: Keys.popupWidth) }
    }

    /// ポップアップ高さ
    @Published var popupHeight: CGFloat {
        didSet { defaults.set(popupHeight, forKey: Keys.popupHeight) }
    }

    /// ポップアップ透過率 (0.0-1.0)
    @Published var popupOpacity: Double {
        didSet { defaults.set(popupOpacity, forKey: Keys.popupOpacity) }
    }

    /// ポップアップ表示時間（秒、0=消えない）
    @Published var popupDuration: Int {
        didSet { defaults.set(popupDuration, forKey: Keys.popupDuration) }
    }

    /// ポップアップ文字サイズ
    @Published var popupFontSize: CGFloat {
        didSet { defaults.set(Double(popupFontSize), forKey: Keys.popupFontSize) }
    }

    // MARK: - Keyboard Shortcuts

    /// 履歴ウィンドウを開くショートカット
    @Published var shortcutOpenHistory: KeyboardShortcut {
        didSet {
            if let data = try? JSONEncoder().encode(shortcutOpenHistory) {
                defaults.set(data, forKey: Keys.shortcutOpenHistory)
            }
        }
    }

    /// 検索フィールドにフォーカスするショートカット
    @Published var shortcutFocusSearch: KeyboardShortcut {
        didSet {
            if let data = try? JSONEncoder().encode(shortcutFocusSearch) {
                defaults.set(data, forKey: Keys.shortcutFocusSearch)
            }
        }
    }

    // MARK: - Hover Preview Settings

    /// ホバープレビュー幅
    @Published var hoverPreviewWidth: CGFloat {
        didSet { defaults.set(hoverPreviewWidth, forKey: Keys.hoverPreviewWidth) }
    }

    /// ホバープレビュー高さ
    @Published var hoverPreviewHeight: CGFloat {
        didSet { defaults.set(hoverPreviewHeight, forKey: Keys.hoverPreviewHeight) }
    }

    /// ホバープレビュー文字サイズ
    @Published var hoverPreviewFontSize: CGFloat {
        didSet { defaults.set(Double(hoverPreviewFontSize), forKey: Keys.hoverPreviewFontSize) }
    }

    // MARK: - Dropdown Settings

    /// ドロップダウン幅
    @Published var dropdownWidth: CGFloat {
        didSet { defaults.set(dropdownWidth, forKey: Keys.dropdownWidth) }
    }

    /// ドロップダウン高さ
    @Published var dropdownHeight: CGFloat {
        didSet { defaults.set(dropdownHeight, forKey: Keys.dropdownHeight) }
    }

    /// ドロップダウン文字サイズ
    @Published var dropdownFontSize: CGFloat {
        didSet { defaults.set(Double(dropdownFontSize), forKey: Keys.dropdownFontSize) }
    }

    // MARK: - Enums

    enum DeleteDelay: Int, CaseIterable {
        case immediately = 0
        case fiveSeconds = 5
        case oneMinute = 60

        var displayName: String {
            switch self {
            case .immediately: return "即座に削除"
            case .fiveSeconds: return "5秒後に削除"
            case .oneMinute: return "1分後に削除"
            }
        }
    }

    enum HoverPreviewMode: String, CaseIterable {
        case recentFive = "recentFive"
        case unreadOnly = "unreadOnly"

        var displayName: String {
            switch self {
            case .recentFive: return "直近5件"
            case .unreadOnly: return "未確認のみ"
            }
        }
    }

    enum RetentionPeriod: Int, CaseIterable {
        case oneDay = 1
        case oneWeek = 7
        case oneMonth = 30
        case unlimited = 0

        var displayName: String {
            switch self {
            case .oneDay: return "24時間"
            case .oneWeek: return "7日間"
            case .oneMonth: return "30日間"
            case .unlimited: return "無制限"
            }
        }

        var days: Int? {
            self == .unlimited ? nil : rawValue
        }
    }

    // MARK: - Init

    private init() {
        // Load from UserDefaults or use defaults
        launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        showUnreadBadge = defaults.object(forKey: Keys.showUnreadBadge) as? Bool ?? true
        autoDeleteFromNotificationCenter = defaults.bool(forKey: Keys.autoDeleteFromNotificationCenter)

        if let delayValue = defaults.object(forKey: Keys.deleteDelay) as? Int,
           let delay = DeleteDelay(rawValue: delayValue) {
            deleteDelay = delay
        } else {
            deleteDelay = .fiveSeconds
        }

        if let modeValue = defaults.string(forKey: Keys.hoverPreviewMode),
           let mode = HoverPreviewMode(rawValue: modeValue) {
            hoverPreviewMode = mode
        } else {
            hoverPreviewMode = .unreadOnly
        }

        if let periodValue = defaults.object(forKey: Keys.retentionPeriod) as? Int,
           let period = RetentionPeriod(rawValue: periodValue) {
            retentionPeriod = period
        } else {
            retentionPeriod = .oneMonth
        }

        excludedApps = defaults.stringArray(forKey: Keys.excludedApps) ?? []

        // ポップアップ設定（デフォルト: 右上、350x100、透過率0.95、5秒）
        popupEnabled = defaults.object(forKey: Keys.popupEnabled) as? Bool ?? true

        // 画面右上のデフォルト位置を計算
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let defaultWidth: CGFloat = 350
        let defaultHeight: CGFloat = 100
        let defaultX = screenFrame.maxX - defaultWidth - 20
        let defaultY = screenFrame.maxY - defaultHeight - 20

        // CGFloatはDoubleとして保存・読み込み
        popupX = CGFloat(defaults.double(forKey: Keys.popupX) != 0 ? defaults.double(forKey: Keys.popupX) : defaultX)
        popupY = CGFloat(defaults.double(forKey: Keys.popupY) != 0 ? defaults.double(forKey: Keys.popupY) : defaultY)
        popupWidth = CGFloat(defaults.double(forKey: Keys.popupWidth) != 0 ? defaults.double(forKey: Keys.popupWidth) : defaultWidth)
        popupHeight = CGFloat(defaults.double(forKey: Keys.popupHeight) != 0 ? defaults.double(forKey: Keys.popupHeight) : defaultHeight)
        popupOpacity = defaults.object(forKey: Keys.popupOpacity) as? Double ?? 0.95
        popupDuration = defaults.object(forKey: Keys.popupDuration) as? Int ?? 5
        popupFontSize = CGFloat(defaults.double(forKey: Keys.popupFontSize) != 0 ? defaults.double(forKey: Keys.popupFontSize) : 14.0)

        // ショートカット設定
        if let data = defaults.data(forKey: Keys.shortcutOpenHistory),
           let shortcut = try? JSONDecoder().decode(KeyboardShortcut.self, from: data) {
            shortcutOpenHistory = shortcut
        } else {
            shortcutOpenHistory = .openHistory
        }

        if let data = defaults.data(forKey: Keys.shortcutFocusSearch),
           let shortcut = try? JSONDecoder().decode(KeyboardShortcut.self, from: data) {
            shortcutFocusSearch = shortcut
        } else {
            shortcutFocusSearch = .focusSearch
        }

        // ホバープレビュー設定（デフォルト: 300x250、11pt）
        hoverPreviewWidth = CGFloat(defaults.double(forKey: Keys.hoverPreviewWidth) != 0 ? defaults.double(forKey: Keys.hoverPreviewWidth) : 300)
        hoverPreviewHeight = CGFloat(defaults.double(forKey: Keys.hoverPreviewHeight) != 0 ? defaults.double(forKey: Keys.hoverPreviewHeight) : 250)
        hoverPreviewFontSize = CGFloat(defaults.double(forKey: Keys.hoverPreviewFontSize) != 0 ? defaults.double(forKey: Keys.hoverPreviewFontSize) : 11.0)

        // ドロップダウン設定（デフォルト: 360x500、13pt）
        dropdownWidth = CGFloat(defaults.double(forKey: Keys.dropdownWidth) != 0 ? defaults.double(forKey: Keys.dropdownWidth) : 360)
        dropdownHeight = CGFloat(defaults.double(forKey: Keys.dropdownHeight) != 0 ? defaults.double(forKey: Keys.dropdownHeight) : 500)
        dropdownFontSize = CGFloat(defaults.double(forKey: Keys.dropdownFontSize) != 0 ? defaults.double(forKey: Keys.dropdownFontSize) : 13.0)
    }

    // MARK: - Methods

    /// アプリを除外リストに追加
    func addExcludedApp(_ bundleId: String) {
        if !excludedApps.contains(bundleId) {
            excludedApps.append(bundleId)
        }
    }

    /// アプリを除外リストから削除
    func removeExcludedApp(_ bundleId: String) {
        excludedApps.removeAll { $0 == bundleId }
    }

    /// アプリが除外されているか
    func isAppExcluded(_ bundleId: String) -> Bool {
        excludedApps.contains(bundleId)
    }

    /// 設定をリセット
    func resetToDefaults() {
        launchAtLogin = false
        showUnreadBadge = true
        autoDeleteFromNotificationCenter = false
        deleteDelay = .fiveSeconds
        hoverPreviewMode = .unreadOnly
        retentionPeriod = .oneMonth
        excludedApps = []

        // ポップアップ設定をリセット
        popupEnabled = true
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        popupWidth = 350
        popupHeight = 100
        popupX = screenFrame.maxX - popupWidth - 20
        popupY = screenFrame.maxY - popupHeight - 20
        popupOpacity = 0.95
        popupDuration = 5
        popupFontSize = 14

        // ショートカット設定をリセット
        shortcutOpenHistory = .openHistory
        shortcutFocusSearch = .focusSearch

        // ホバープレビュー設定をリセット
        hoverPreviewWidth = 300
        hoverPreviewHeight = 250
        hoverPreviewFontSize = 11.0

        // ドロップダウン設定をリセット
        dropdownWidth = 360
        dropdownHeight = 500
        dropdownFontSize = 13.0
    }

    /// ポップアップの現在のフレームを取得
    var popupFrame: NSRect {
        NSRect(x: popupX, y: popupY, width: popupWidth, height: popupHeight)
    }

    /// ポップアップのフレームを設定
    func setPopupFrame(_ frame: NSRect) {
        popupX = frame.origin.x
        popupY = frame.origin.y
        popupWidth = frame.width
        popupHeight = frame.height
    }
}
