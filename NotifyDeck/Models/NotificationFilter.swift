import Foundation

/// 通知フィルタ条件
struct NotificationFilter {
    var appIdentifiers: [String]?
    var searchQuery: String?
    var dateRange: ClosedRange<Date>?
    var isReadFilter: Bool?

    init(
        appIdentifiers: [String]? = nil,
        searchQuery: String? = nil,
        dateRange: ClosedRange<Date>? = nil,
        isReadFilter: Bool? = nil
    ) {
        self.appIdentifiers = appIdentifiers
        self.searchQuery = searchQuery
        self.dateRange = dateRange
        self.isReadFilter = isReadFilter
    }

    /// フィルタが空かどうか
    var isEmpty: Bool {
        appIdentifiers == nil &&
        (searchQuery == nil || searchQuery?.isEmpty == true) &&
        dateRange == nil &&
        isReadFilter == nil
    }

    /// 通知がフィルタ条件に一致するかチェック
    func matches(_ notification: NotificationItem) -> Bool {
        // アプリフィルタ
        if let apps = appIdentifiers, !apps.isEmpty {
            guard apps.contains(notification.appIdentifier) else { return false }
        }

        // 検索クエリ
        if let query = searchQuery, !query.isEmpty {
            let lowercasedQuery = query.lowercased()
            let matchesTitle = notification.title.lowercased().contains(lowercasedQuery)
            let matchesBody = notification.body.lowercased().contains(lowercasedQuery)
            let matchesApp = notification.appName.lowercased().contains(lowercasedQuery)
            guard matchesTitle || matchesBody || matchesApp else { return false }
        }

        // 日付範囲
        if let range = dateRange {
            guard range.contains(notification.timestamp) else { return false }
        }

        // 既読/未読フィルタ
        if let isRead = isReadFilter {
            guard notification.isRead == isRead else { return false }
        }

        return true
    }
}

// MARK: - Preset Filters

extension NotificationFilter {
    /// 未読のみ
    static var unreadOnly: NotificationFilter {
        NotificationFilter(isReadFilter: false)
    }

    /// 今日のみ
    static var todayOnly: NotificationFilter {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        return NotificationFilter(dateRange: startOfDay...endOfDay)
    }

    /// 過去7日間
    static var lastWeek: NotificationFilter {
        let now = Date()
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        return NotificationFilter(dateRange: weekAgo...now)
    }
}
