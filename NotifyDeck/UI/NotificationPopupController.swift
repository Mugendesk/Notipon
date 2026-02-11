import SwiftUI
import AppKit
import Combine

/// カスタム通知ポップアップを管理
final class NotificationPopupController: ObservableObject {
    static let shared = NotificationPopupController()

    private var popupWindow: NSWindow?
    private var hostingView: NSHostingView<AnyView>?
    private var dismissTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var settingsManager: SettingsManager { SettingsManager.shared }
    private var isUpdatingFromSettings = false  // 無限ループ防止フラグ

    /// 現在表示中の通知
    @Published var currentNotification: NotificationItem?

    /// 通知キュー（複数通知が同時に来た場合）
    private var notificationQueue: [NotificationItem] = []

    private init() {
        observeSettings()
        // ウィンドウを事前作成（初回表示を高速化）
        DispatchQueue.main.async { [weak self] in
            self?.preloadWindow()
        }
    }

    /// ウィンドウを事前作成してレンダリングを完了させる
    private func preloadWindow() {
        createWindow()
        // 一瞬表示してSwiftUIをレンダリング
        popupWindow?.orderFront(nil)
        popupWindow?.orderOut(nil)
    }

    // MARK: - Settings Observer

    private func observeSettings() {
        // 各設定を個別に監視（CombineLatest4だと順序問題が起きる可能性）
        settingsManager.$popupX
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.applyCurrentFrame() }
            .store(in: &cancellables)

        settingsManager.$popupY
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.applyCurrentFrame() }
            .store(in: &cancellables)

        settingsManager.$popupWidth
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.applyCurrentFrame() }
            .store(in: &cancellables)

        settingsManager.$popupHeight
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.applyCurrentFrame() }
            .store(in: &cancellables)

        settingsManager.$popupOpacity
            .receive(on: DispatchQueue.main)
            .sink { [weak self] opacity in
                self?.popupWindow?.alphaValue = opacity
            }
            .store(in: &cancellables)
    }

    private func applyCurrentFrame() {
        let frame = NSRect(
            x: settingsManager.popupX,
            y: settingsManager.popupY,
            width: settingsManager.popupWidth,
            height: settingsManager.popupHeight
        )
        updateWindowFrame(frame)
    }

    // MARK: - Show Notification

    /// 通知をポップアップ表示
    func show(_ notification: NotificationItem) {
        guard settingsManager.popupEnabled else { return }

        // 既にポップアップが表示中なら、キューに追加
        if self.currentNotification != nil {
            self.notificationQueue.append(notification)
            return
        }

        self.currentNotification = notification
        self.showPopupWindow()
        self.startDismissTimer()
    }

    /// 複数の通知を一度に表示（最新のみ表示）
    func showMultiple(_ notifications: [NotificationItem]) {
        guard !notifications.isEmpty else { return }

        // 最新の通知のみ表示
        if let latest = notifications.first {
            show(latest)
        }
    }

    // MARK: - Window Management

    private func showPopupWindow() {
        if popupWindow == nil {
            createWindow()
        }
        // contentはObservableObjectで自動更新
        popupWindow?.alphaValue = settingsManager.popupOpacity
        popupWindow?.orderFront(nil)
    }

    private func createWindow() {
        let frame = settingsManager.popupFrame

        let window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.isMovableByWindowBackground = true
        window.hasShadow = true
        window.alphaValue = 0  // 初期は非表示

        // SwiftUI View を事前作成（ObservableObjectで更新）
        let contentView = PopupContentView(controller: self)
            .environmentObject(settingsManager)
        let hosting = NSHostingView(rootView: AnyView(contentView))
        window.contentView = hosting
        hostingView = hosting

        // ドラッグで位置変更時に設定を保存
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove),
            name: NSWindow.didMoveNotification,
            object: window
        )

        popupWindow = window
    }

    @objc private func windowDidMove(_ notification: Notification) {
        // 設定からの更新中は保存をスキップ（無限ループ防止）
        guard !isUpdatingFromSettings else { return }
        guard let window = notification.object as? NSWindow else { return }
        settingsManager.setPopupFrame(window.frame)
    }

    private func updateWindowFrame(_ frame: NSRect) {
        isUpdatingFromSettings = true
        popupWindow?.setFrame(frame, display: true, animate: false)
        // 少し遅延してフラグをリセット
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.isUpdatingFromSettings = false
        }
    }

    // MARK: - Dismiss

    private func startDismissTimer() {
        dismissTimer?.invalidate()

        let duration = settingsManager.popupDuration
        guard duration > 0 else { return }  // 0秒なら自動消去しない

        dismissTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(duration), repeats: false) { [weak self] _ in
            self?.dismiss()
        }
    }

    func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil

        // フェードアウトアニメーション
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            popupWindow?.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.popupWindow?.orderOut(nil)
            self?.currentNotification = nil

            // キューに次の通知があれば表示
            if let next = self?.notificationQueue.first {
                self?.notificationQueue.removeFirst()
                self?.show(next)
            }
        })
    }

    /// 手動で即座に閉じる
    func dismissImmediately() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        popupWindow?.orderOut(nil)
        currentNotification = nil
        notificationQueue.removeAll()
    }

    // MARK: - Action

    private func handleAction() {
        // 通知クリック時のアクション（将来拡張用）
        dismiss()
    }

    // MARK: - Preview Mode (設定画面用)

    /// プレビュー表示（設定画面から位置を確認）
    func showPreview() {
        let sampleNotification = NotificationItem(
            appIdentifier: "com.example.preview",
            appName: "プレビュー",
            title: "通知タイトル",
            body: "これはプレビュー通知です。ドラッグで位置を変更できます。"
        )

        currentNotification = sampleNotification
        showPopupWindow()

        // プレビューは5秒で自動消去
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
            self?.dismiss()
        }
    }
}

// MARK: - PopupContentView (ObservableObject対応)

private struct PopupContentView: View {
    @ObservedObject var controller: NotificationPopupController
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        Group {
            if let notification = controller.currentNotification {
                NotificationPopupView(
                    notification: notification,
                    onDismiss: { controller.dismiss() },
                    onAction: { controller.dismiss() }
                )
            } else {
                Color.clear
            }
        }
    }
}
