import SwiftUI
import AppKit

/// アプリアイコンキャッシュ
class AppIconCache {
    static let shared = AppIconCache()
    private var cache: [String: NSImage] = [:]
    private let queue = DispatchQueue(label: "com.notifydeck.iconcache")

    func icon(for bundleIdentifier: String) -> NSImage? {
        queue.sync {
            if let cached = cache[bundleIdentifier] {
                return cached
            }

            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                cache[bundleIdentifier] = icon
                return icon
            }

            return nil
        }
    }
}

/// アプリアイコン表示
struct AppIconView: View {
    let bundleIdentifier: String
    let size: CGFloat

    @State private var icon: NSImage?

    var body: some View {
        Group {
            if let icon = icon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: size * 0.6))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: size, height: size)
        .cornerRadius(size * 0.2)
        .onAppear {
            loadIcon()
        }
    }

    private func loadIcon() {
        DispatchQueue.global(qos: .userInitiated).async {
            if let cached = AppIconCache.shared.icon(for: bundleIdentifier) {
                DispatchQueue.main.async {
                    self.icon = cached
                }
            }
        }
    }
}

/// 通知行コンポーネント
struct NotificationRow: View {
    let notification: NotificationItem
    var compact: Bool = false
    @EnvironmentObject var settingsManager: SettingsManager

    private var fontSize: CGFloat {
        compact ? settingsManager.dropdownFontSize : settingsManager.dropdownFontSize
    }

    private var iconSize: CGFloat {
        compact ? settingsManager.dropdownFontSize * 1.8 : 28
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // 未読インジケーター
            Circle()
                .fill(notification.isRead ? Color.clear : Color.accentColor)
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            // アプリアイコン
            AppIconView(bundleIdentifier: notification.appIdentifier, size: iconSize)

            // コンテンツ
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(notification.appName)
                        .font(.system(size: fontSize * 0.9))
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(notification.dateTimeString)
                        .font(.system(size: fontSize * 0.9))
                        .foregroundColor(.secondary)
                }

                Text(notification.title)
                    .font(.system(size: fontSize))
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(notification.body)
                    .font(.system(size: fontSize * 0.9))
                    .foregroundColor(.secondary)
                    .lineLimit(compact ? 1 : 2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

// MARK: - Notification Row Styles

extension NotificationRow {
    /// コンパクトスタイル（ドロップダウン用）
    static func compact(_ notification: NotificationItem) -> NotificationRow {
        NotificationRow(notification: notification, compact: true)
    }

    /// フルスタイル（履歴ウィンドウ用）
    static func full(_ notification: NotificationItem) -> NotificationRow {
        NotificationRow(notification: notification, compact: false)
    }
}

#Preview {
    VStack(spacing: 0) {
        NotificationRow(notification: NotificationItem.samples[0], compact: false)
        Divider()
        NotificationRow(notification: NotificationItem.samples[1], compact: true)
        Divider()
        NotificationRow(notification: NotificationItem.samples[2], compact: true)
    }
    .frame(width: 350)
    .background(Color(NSColor.windowBackgroundColor))
}
