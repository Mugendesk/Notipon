import SwiftUI
import AppKit
import Combine

/// メニューバーコントローラー（ホバー対応）
final class MenuBarController: NSObject, ObservableObject {
    private var statusItem: NSStatusItem!
    private var hoverPopover: NSPopover!
    private var dropdownPopover: NSPopover!
    private var historyWindow: NSWindow?
    private var hoverTimer: Timer?
    private var hoverHandler: HoverHandler?

    private var storageManager: StorageManager { StorageManager.shared }
    private var settingsManager: SettingsManager { SettingsManager.shared }
    private var cancellables = Set<AnyCancellable>()

    @Published private(set) var isHoverPreviewShown = false

    override init() {
        super.init()
        setupStatusItem()
        setupPopovers()
        observeUnreadCount()
        setupGlobalHotkeys()
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem.button else { return }

        updateIcon()

        // アクション設定
        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        // ホバー検知用のハンドラーを設定
        hoverHandler = HoverHandler(
            onMouseEntered: { [weak self] in self?.handleMouseEntered() },
            onMouseExited: { [weak self] in self?.handleMouseExited() }
        )

        let trackingArea = NSTrackingArea(
            rect: button.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: hoverHandler,
            userInfo: nil
        )
        button.addTrackingArea(trackingArea)
    }

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return }

        // ホバープレビューを閉じる
        hideHoverPreview()

        if event.type == .rightMouseUp {
            openHistoryWindow()
        } else {
            toggleDropdown()
        }
    }

    private func setupPopovers() {
        // ホバープレビュー用ポップオーバー
        hoverPopover = NSPopover()
        hoverPopover.contentSize = NSSize(
            width: settingsManager.hoverPreviewWidth,
            height: settingsManager.hoverPreviewHeight
        )
        hoverPopover.behavior = .semitransient
        hoverPopover.animates = true
        hoverPopover.contentViewController = NSHostingController(
            rootView: HoverPreviewView()
                .environmentObject(storageManager)
                .environmentObject(settingsManager)
        )

        // ドロップダウン用ポップオーバー
        dropdownPopover = NSPopover()
        dropdownPopover.contentSize = NSSize(
            width: settingsManager.dropdownWidth,
            height: settingsManager.dropdownHeight
        )
        dropdownPopover.behavior = .transient
        dropdownPopover.animates = true
        dropdownPopover.contentViewController = NSHostingController(
            rootView: DropdownView(
                onOpenHistory: { [weak self] in self?.openHistoryWindow() },
                onOpenSettings: { [weak self] in self?.openSettings() }
            )
            .environmentObject(storageManager)
            .environmentObject(settingsManager)
        )
    }

    // MARK: - Icon Update

    private func updateIcon() {
        guard let button = statusItem.button else { return }

        let unreadCount = storageManager.unreadCount
        let showBadge = settingsManager.showUnreadBadge && unreadCount > 0

        // ベースアイコン（白色で固定）
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        guard let symbolImage = NSImage(systemSymbolName: "bell.fill", accessibilityDescription: "NotifyDeck")?.withSymbolConfiguration(config) else { return }

        let whiteIcon = createWhiteIcon(from: symbolImage)

        if showBadge {
            // バッジ付きアイコン
            let badgeImage = createBadgeImage(base: whiteIcon, count: unreadCount)
            button.image = badgeImage
        } else {
            button.image = whiteIcon
        }
    }

    private func createWhiteIcon(from symbol: NSImage) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)

        image.lockFocus()

        // 白い矩形を描画
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()

        // シンボルでマスキング（destinationInで白い部分だけシンボルの形に切り抜く）
        symbol.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .destinationIn, fraction: 1.0)

        image.unlockFocus()

        return image
    }

    private func createBadgeImage(base: NSImage, count: Int) -> NSImage {
        let size = NSSize(width: 22, height: 18)
        let image = NSImage(size: size)

        image.lockFocus()

        // 白いベルアイコンを描画
        base.draw(
            in: NSRect(x: 0, y: 0, width: 18, height: 18),
            from: .zero,
            operation: .sourceOver,
            fraction: 1.0
        )

        // バッジ（赤い丸）
        let badgeRect = NSRect(x: 12, y: 10, width: 10, height: 10)
        NSColor.systemRed.setFill()
        NSBezierPath(ovalIn: badgeRect).fill()

        // バッジ数字（9以下のみ）
        if count <= 9 {
            let text = "\(count)"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 7, weight: .bold),
                .foregroundColor: NSColor.white
            ]
            let textSize = text.size(withAttributes: attributes)
            let textRect = NSRect(
                x: badgeRect.midX - textSize.width / 2,
                y: badgeRect.midY - textSize.height / 2 + 0.5,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: textRect, withAttributes: attributes)
        }

        image.unlockFocus()

        return image
    }

    private func observeUnreadCount() {
        storageManager.$unreadCount
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateIcon()
            }
            .store(in: &cancellables)

        settingsManager.$showUnreadBadge
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateIcon()
            }
            .store(in: &cancellables)

        // ホバープレビューのサイズ変更を監視
        settingsManager.$hoverPreviewWidth
            .receive(on: DispatchQueue.main)
            .sink { [weak self] width in
                self?.hoverPopover.contentSize.width = width
            }
            .store(in: &cancellables)

        settingsManager.$hoverPreviewHeight
            .receive(on: DispatchQueue.main)
            .sink { [weak self] height in
                self?.hoverPopover.contentSize.height = height
            }
            .store(in: &cancellables)

        // ドロップダウンのサイズ変更を監視
        settingsManager.$dropdownWidth
            .receive(on: DispatchQueue.main)
            .sink { [weak self] width in
                self?.dropdownPopover.contentSize.width = width
            }
            .store(in: &cancellables)

        settingsManager.$dropdownHeight
            .receive(on: DispatchQueue.main)
            .sink { [weak self] height in
                self?.dropdownPopover.contentSize.height = height
            }
            .store(in: &cancellables)
    }

    // MARK: - Mouse Events

    private func handleMouseEntered() {
        // 少し遅延してホバープレビューを表示
        hoverTimer?.invalidate()
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            self?.showHoverPreview()
        }
    }

    private func handleMouseExited() {
        hoverTimer?.invalidate()
        hoverTimer = nil

        // ドロップダウンが表示されていなければプレビューを閉じる
        if !dropdownPopover.isShown {
            hideHoverPreview()
        }
    }

    // MARK: - Popover Control

    private func showHoverPreview() {
        guard let button = statusItem.button,
              !dropdownPopover.isShown,
              !hoverPopover.isShown else { return }

        hoverPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        isHoverPreviewShown = true
    }

    private func hideHoverPreview() {
        if hoverPopover.isShown {
            hoverPopover.performClose(nil)
        }
        isHoverPreviewShown = false
    }

    private func toggleDropdown() {
        guard let button = statusItem.button else { return }

        if dropdownPopover.isShown {
            dropdownPopover.performClose(nil)
        } else {
            dropdownPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - History Window

    func openHistoryWindow() {
        dropdownPopover.performClose(nil)

        // 既存のウィンドウがあり、表示されている場合はトグル（閉じる）
        if let window = historyWindow, window.isVisible {
            window.close()
            return
        }

        // ウィンドウが存在するが非表示の場合は表示
        if let window = historyWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // ウィンドウが存在しない場合は新規作成
        let contentView = HistoryWindowView()
            .environmentObject(storageManager)
            .environmentObject(settingsManager)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "NotifyDeck"
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        window.setFrameAutosaveName("NotifyDeckHistoryWindow")
        window.isReleasedWhenClosed = false

        historyWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Settings

    func openSettings() {
        dropdownPopover.performClose(nil)

        // Settings window
        let contentView = SettingsView()
            .environmentObject(settingsManager)
            .environmentObject(storageManager)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 550),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "設定"
        window.contentView = NSHostingView(rootView: contentView)
        window.center()

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Global Hotkeys

    private func setupGlobalHotkeys() {
        // 履歴ウィンドウを開くショートカット（設定から取得）
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }

            let shortcut = self.settingsManager.shortcutOpenHistory

            // ショートカットが設定されていて、イベントと一致するか確認
            if !shortcut.isDisabled && shortcut.matches(event: event) {
                self.openHistoryWindow()
                return nil  // イベントを消費
            }

            return event
        }

        // ショートカット設定の変更を監視（再起動が必要）
        settingsManager.$shortcutOpenHistory
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // 設定変更時の処理（必要に応じて実装）
            }
            .store(in: &cancellables)
    }
}

// MARK: - Hover Handler

/// NSTrackingAreaのownerとして使用するヘルパークラス
final class HoverHandler: NSResponder {
    private let onMouseEntered: () -> Void
    private let onMouseExited: () -> Void

    init(onMouseEntered: @escaping () -> Void, onMouseExited: @escaping () -> Void) {
        self.onMouseEntered = onMouseEntered
        self.onMouseExited = onMouseExited
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseEntered(with event: NSEvent) {
        onMouseEntered()
    }

    override func mouseExited(with event: NSEvent) {
        onMouseExited()
    }
}
