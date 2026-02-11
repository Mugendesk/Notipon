import SwiftUI
import AppKit

/// カスタム通知ポップアップのUI
struct NotificationPopupView: View {
    let notification: NotificationItem
    let onDismiss: () -> Void
    let onAction: () -> Void

    @EnvironmentObject var settingsManager: SettingsManager
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            // アプリアイコン
            appIcon
                .frame(width: 40, height: 40)

            // 通知内容
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(notification.appName)
                        .font(.system(size: settingsManager.popupFontSize * 0.8))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(notification.timeString)
                        .font(.system(size: settingsManager.popupFontSize * 0.7))
                        .foregroundColor(.secondary)
                }

                Text(notification.title)
                    .font(.system(size: settingsManager.popupFontSize, weight: .semibold))
                    .lineLimit(1)

                if let subtitle = notification.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: settingsManager.popupFontSize * 0.9))
                        .foregroundColor(.primary.opacity(0.8))
                        .lineLimit(1)
                }

                if !notification.body.isEmpty {
                    Text(notification.body)
                        .font(.system(size: settingsManager.popupFontSize * 0.85))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            // 閉じるボタン（ホバー時のみ表示）
            if isHovering {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onAction()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }

    // MARK: - App Icon / Image

    @ViewBuilder
    private var appIcon: some View {
        // 通知に画像データがあればそれを表示（ジャケット画像など）
        if let imageData = notification.imageData,
           let nsImage = NSImage(data: imageData) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else if let icon = getAppIcon(for: notification.appIdentifier) {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: notification.appIconName)
                .font(.system(size: 24))
                .foregroundColor(.accentColor)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.1))
                )
        }
    }

    private func getAppIcon(for bundleId: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}

// MARK: - Preview

#Preview {
    NotificationPopupView(
        notification: NotificationItem.samples[0],
        onDismiss: {},
        onAction: {}
    )
    .environmentObject(SettingsManager.shared)
    .frame(width: 350, height: 100)
    .padding()
    .background(Color.gray.opacity(0.3))
}
