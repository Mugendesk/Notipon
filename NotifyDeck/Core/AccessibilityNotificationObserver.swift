import Cocoa
import ApplicationServices

/// Accessibility APIで通知バナーを即時検知（アダプティブポーリング）
final class AccessibilityNotificationObserver {
    static let shared = AccessibilityNotificationObserver()

    private var observer: AXObserver?
    private var pollingTimer: Timer?
    private var lastNotificationText: String?
    private var seenNotifications = Set<String>()  // 既に見た通知を記録

    // アダプティブポーリング
    private static let idleInterval: TimeInterval = 3.0
    private static let activeInterval: TimeInterval = 0.05
    private static let cooldownIntervals: [TimeInterval] = [0.2, 0.5, 1.0, 3.0]

    private enum PollingState { case idle, active, cooldown }
    private var pollingState: PollingState = .idle
    private var activePollCount = 0
    private var cooldownStep = 0
    private static let maxActivePollCount = 100  // アクティブ5秒（50ms×100）
    private var axApp: AXUIElement?

    private init() {}

    // MARK: - Start/Stop

    func startObserving() {
        // アクセシビリティ権限チェック
        guard AXIsProcessTrusted() else {
            NSLog("AccessibilityObserver: アクセシビリティ権限がありません")
            requestAccessibilityPermission()
            return
        }

        NSLog("AccessibilityObserver: 監視開始")

        // NotificationCenterUIのPIDを取得
        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == "com.apple.notificationcenterui"
        }) else {
            NSLog("AccessibilityObserver: NotificationCenterUI not found")
            return
        }

        let pid = app.processIdentifier
        NSLog("AccessibilityObserver: NotificationCenterUI PID = %d", pid)

        // AXObserverを作成
        var obs: AXObserver?
        let result = AXObserverCreate(pid, axCallback, &obs)
        if result != .success {
            NSLog("AccessibilityObserver: AXObserverCreate failed: %d", result.rawValue)
            // フォールバック: ポーリング
            startPolling(pid: pid)
            return
        }

        observer = obs

        let axApp = AXUIElementCreateApplication(pid)

        // 通知を監視
        let notifications: [String] = [
            kAXCreatedNotification,
            kAXUIElementDestroyedNotification,
            kAXFocusedUIElementChangedNotification,
            kAXWindowCreatedNotification,
            kAXValueChangedNotification
        ]

        for notification in notifications {
            AXObserverAddNotification(obs!, axApp, notification as CFString, nil)
        }

        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(obs!),
            .defaultMode
        )

        // ポーリング併用（アイドル間隔で開始）
        self.axApp = axApp
        startPolling(pid: pid)
    }

    /// AXObserverイベントを受信した時（外部から呼ばれる）
    func onAXEvent() {
        guard pollingTimer != nil else { return }
        transitionToActive()
        // NotificationMonitorもアクティブに
        NotificationMonitor.shared.triggerActivePolling()
    }

    func stopObserving() {
        pollingTimer?.invalidate()
        pollingTimer = nil

        if let obs = observer {
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(obs),
                .defaultMode
            )
        }
        observer = nil

        NSLog("AccessibilityObserver: 監視停止")
    }

    // MARK: - アダプティブポーリング

    private func transitionToActive() {
        guard pollingState != .active else { return }
        pollingState = .active
        activePollCount = 0
        reschedulePolling(interval: Self.activeInterval)
    }

    private func transitionToCooldown() {
        pollingState = .cooldown
        cooldownStep = 0
        reschedulePolling(interval: Self.cooldownIntervals[0])
    }

    private func transitionToIdle() {
        pollingState = .idle
        reschedulePolling(interval: Self.idleInterval)
    }

    private func reschedulePolling(interval: TimeInterval) {
        pollingTimer?.invalidate()
        guard let axApp = self.axApp else { return }
        pollingTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.scanForNotificationBanner(axApp: axApp)
        }
    }

    private func startPolling(pid: pid_t) {
        self.axApp = AXUIElementCreateApplication(pid)
        reschedulePolling(interval: Self.idleInterval)
        pollingState = .idle
        NSLog("AccessibilityObserver: ポーリング開始 (adaptive: idle=%.1fs)", Self.idleInterval)
    }

    private func scanForNotificationBanner(axApp: AXUIElement) {
        // ウィンドウを取得
        var windowsValue: AnyObject?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsValue) == .success,
              let windows = windowsValue as? [AXUIElement] else {
            advancePollingState(foundNotification: false)
            return
        }

        var foundNew = false

        for window in windows {
            // 通知バナーかどうかを位置とサイズで判定
            if !isNotificationBanner(window) {
                continue
            }

            // ウィンドウの子要素を探索
            if let notification = extractNotificationFromElement(window) {
                // 重複チェック
                let key = "\(notification.title)|\(notification.body)"

                // 既に見た通知はスキップ（通知センター開いた時の誤検知を防ぐ）
                if seenNotifications.contains(key) {
                    continue
                }

                if key != lastNotificationText {
                    lastNotificationText = key
                    seenNotifications.insert(key)
                    foundNew = true

                    // 一定時間後にSetから削除（同じ通知が再度来た時に対応）
                    DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                        self?.seenNotifications.remove(key)
                    }

                    NSLog("AccessibilityObserver: 🔔 通知検知 - %@: %@", notification.title, notification.body)

                    // ポップアップ表示
                    DispatchQueue.main.async {
                        let item = NotificationItem(
                            appIdentifier: notification.appId ?? "unknown",
                            appName: notification.appName ?? "通知",
                            title: notification.title,
                            body: notification.body
                        )
                        NotificationPopupController.shared.show(item)
                    }

                    // NotificationMonitorもアクティブに
                    NotificationMonitor.shared.triggerActivePolling()
                }
            }
        }

        advancePollingState(foundNotification: foundNew)
    }

    /// ポーリング状態を進める
    private func advancePollingState(foundNotification: Bool) {
        if foundNotification {
            // 検知したらアクティブを延長
            if pollingState != .active {
                transitionToActive()
            }
            activePollCount = 0
            return
        }

        switch pollingState {
        case .active:
            activePollCount += 1
            if activePollCount >= Self.maxActivePollCount {
                transitionToCooldown()
            }
        case .cooldown:
            cooldownStep += 1
            if cooldownStep < Self.cooldownIntervals.count {
                reschedulePolling(interval: Self.cooldownIntervals[cooldownStep])
            } else {
                transitionToIdle()
            }
        case .idle:
            break
        }
    }

    // 通知バナーかどうかを判定（通知センターと区別）
    private func isNotificationBanner(_ window: AXUIElement) -> Bool {
        // ウィンドウの位置を取得
        var positionValue: AnyObject?
        var position = CGPoint.zero
        if AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue) == .success {
            AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
        } else {
            return false
        }

        // ウィンドウのサイズを取得
        var sizeValue: AnyObject?
        var size = CGSize.zero
        if AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success {
            AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        } else {
            return false
        }

        // 通知バナーの特徴:
        // 1. 高さが小さい（80-150px程度）
        // 2. Y座標が画面上部付近
        // 3. X座標が画面右側

        let screenFrame = NSScreen.main?.frame ?? .zero
        let isSmallHeight = size.height < 200  // 通知バナーは高さが小さい
        let isTopPosition = position.y < screenFrame.height && position.y > screenFrame.height - 200  // 画面上部（macOSは下原点）
        let isRightSide = position.x > (screenFrame.width - 600)  // 画面右側

        return isSmallHeight && isTopPosition && isRightSide
    }

    private struct NotificationData {
        var title: String
        var body: String
        var appName: String?
        var appId: String?
    }

    private func extractNotificationFromElement(_ element: AXUIElement) -> NotificationData? {
        var title = ""
        var body = ""
        var appName: String?

        // 子要素があるか確認
        var childrenValue: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue) == .success,
              childrenValue as? [AXUIElement] != nil else {
            return nil
        }

        // 再帰的にテキスト要素を探す
        var texts: [String] = []
        collectTexts(from: element, into: &texts, depth: 0)

        // テキストが2つ以上あれば通知とみなす
        if texts.count >= 2 {
            // "Notification Center" をスキップしてパース
            let filteredTexts = texts.filter { $0 != "Notification Center" && $0 != "通知センター" }

            if filteredTexts.count >= 2 {
                // アプリ名, タイトル, 本文 の順
                if filteredTexts.count >= 3 {
                    appName = filteredTexts[0]
                    title = filteredTexts[1]
                    body = filteredTexts[2...].joined(separator: " ")
                } else {
                    title = filteredTexts[0]
                    body = filteredTexts[1]
                }
                return NotificationData(title: title, body: body, appName: appName, appId: nil)
            } else if filteredTexts.count == 1 && texts.count >= 2 {
                // "Notification Center" + 1つだけ = タイトルのみ
                title = filteredTexts[0]
                body = ""
                return NotificationData(title: title, body: body, appName: nil, appId: nil)
            }
        }

        return nil
    }

    private func collectTexts(from element: AXUIElement, into texts: inout [String], depth: Int) {
        guard depth < 10 else { return }  // 深さ制限

        // このエレメントのテキストを取得
        var value: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value) == .success,
           let text = value as? String, !text.isEmpty {
            texts.append(text)
        }

        // タイトルも取得
        if AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &value) == .success,
           let text = value as? String, !text.isEmpty {
            texts.append(text)
        }

        // 子要素を再帰的に探索
        var childrenValue: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue) == .success,
           let children = childrenValue as? [AXUIElement] {
            for child in children {
                collectTexts(from: child, into: &texts, depth: depth + 1)
            }
        }
    }

    // MARK: - Permission

    private func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}

// AXObserverのコールバック → アダプティブポーリングをアクティブに切り替え
private func axCallback(
    observer: AXObserver,
    element: AXUIElement,
    notification: CFString,
    refcon: UnsafeMutableRawPointer?
) {
    DispatchQueue.main.async {
        AccessibilityNotificationObserver.shared.onAXEvent()
    }
}
