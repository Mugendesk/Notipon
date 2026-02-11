import Foundation
import AppKit

/// 通知センターの自動削除
final class NotificationCleaner {
    static let shared = NotificationCleaner()

    private init() {}

    /// 通知センターをクリア（AppleScript経由）
    func clearNotificationCenter() {
        let script = """
        tell application "System Events"
            try
                set _groups to groups of UI element 1 of scroll area 1 of group 1 of window "Notification Center" of application process "NotificationCenter"
                repeat with _group in _groups
                    set _actions to actions of _group
                    repeat with _action in _actions
                        if name of _action is "Clear All" then
                            perform _action
                        else if name of _action is "Close" then
                            perform _action
                        end if
                    end repeat
                end repeat
            end try
        end tell
        """

        runAppleScript(script)
    }

    /// 特定アプリの通知のみクリア
    func clearNotificationsFor(appName: String) {
        let script = """
        tell application "System Events"
            try
                set _groups to groups of UI element 1 of scroll area 1 of group 1 of window "Notification Center" of application process "NotificationCenter"
                repeat with _group in _groups
                    if (name of static text 1 of _group) contains "\(appName)" then
                        set _actions to actions of _group
                        repeat with _action in _actions
                            if name of _action is "Clear All" or name of _action is "Close" then
                                perform _action
                            end if
                        end repeat
                    end if
                end repeat
            end try
        end tell
        """

        runAppleScript(script)
    }

    /// 通知センターを開く
    func openNotificationCenter() {
        let script = """
        tell application "System Events"
            tell process "ControlCenter"
                try
                    click menu bar item "Clock" of menu bar 1
                on error
                    -- macOS Ventura以降
                    click menu bar item 1 of menu bar 2
                end try
            end tell
        end tell
        """

        runAppleScript(script)
    }

    // MARK: - AppleScript Execution

    private func runAppleScript(_ source: String) {
        DispatchQueue.global(qos: .utility).async {
            var error: NSDictionary?
            if let script = NSAppleScript(source: source) {
                script.executeAndReturnError(&error)
                if let error = error {
                    print("AppleScript error: \(error)")
                }
            }
        }
    }

    // MARK: - Alternative Methods

    /// 通知センターを閉じて通知を非表示にする
    func dismissNotificationCenter() {
        let script = """
        tell application "System Events"
            try
                keystroke escape
            end try
        end tell
        """

        runAppleScript(script)
    }

    /// おやすみモードをトグル
    func toggleDoNotDisturb() {
        let script = """
        tell application "System Events"
            tell process "ControlCenter"
                click menu bar item "Focus" of menu bar 1
                delay 0.5
                click button 1 of group 1 of window 1
            end tell
        end tell
        """

        runAppleScript(script)
    }
}
