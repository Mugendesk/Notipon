import SwiftUI
import ServiceManagement

/// 設定画面
struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var storageManager: StorageManager

    @State private var showingClearConfirmation = false
    @State private var showingAddAppSheet = false
    @State private var showingLoadTestConfirmation = false
    @State private var isLoadTestRunning = false
    @State private var loadTestError: String?
    @State private var loadTestCompleted = false

    // 画面サイズ（ポップアップ位置スライダー用）
    private var maxScreenX: CGFloat {
        (NSScreen.main?.frame.width ?? 1920) - settingsManager.popupWidth
    }
    private var maxScreenY: CGFloat {
        (NSScreen.main?.frame.height ?? 1080) - settingsManager.popupHeight
    }

    var body: some View {
        Form {
            // 一般設定
            generalSection

            // キーボードショートカット
            keyboardShortcutsSection

            // 通知センター設定
            notificationCenterSection

            // ホバープレビュー設定
            hoverPreviewSection

            // ドロップダウン設定
            dropdownSection

            // ポップアップ設定
            popupSection

            // 保存期間設定
            retentionSection

            // 除外アプリ設定
            excludedAppsSection

            // データ管理
            dataSection

            // About
            aboutSection
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 800)
        .alert("履歴をクリア", isPresented: $showingClearConfirmation) {
            Button("キャンセル", role: .cancel) {}
            Button("クリア", role: .destructive) {
                try? storageManager.deleteAll()
            }
        } message: {
            Text("すべての通知履歴を削除します。この操作は取り消せません。")
        }
        .alert("負荷テスト", isPresented: $showingLoadTestConfirmation) {
            Button("キャンセル", role: .cancel) {}
            Button("実行") {
                runLoadTest()
            }
        } message: {
            Text("1000件のテスト通知を生成します。データベースのサイズが増加します。よろしいですか？")
        }
        .alert("負荷テスト完了", isPresented: $loadTestCompleted) {
            Button("OK") {
                loadTestCompleted = false
                loadTestError = nil
            }
        } message: {
            if let error = loadTestError {
                Text("エラーが発生しました: \(error)")
            } else {
                Text("1000件のテスト通知を生成しました。")
            }
        }
        .sheet(isPresented: $showingAddAppSheet) {
            AddExcludedAppView(settingsManager: settingsManager)
        }
    }

    // MARK: - General

    private var generalSection: some View {
        Section("一般") {
            Toggle("ログイン時に起動", isOn: $settingsManager.launchAtLogin)
                .onChange(of: settingsManager.launchAtLogin) { newValue in
                    updateLoginItem(enabled: newValue)
                }

            Toggle("メニューバーに未読バッジを表示", isOn: $settingsManager.showUnreadBadge)
        }
    }

    // MARK: - Keyboard Shortcuts

    private var keyboardShortcutsSection: some View {
        Section("キーボードショートカット") {
            HStack {
                Text("履歴ウィンドウを開く")
                    .frame(width: 150, alignment: .leading)
                KeyRecorderView(shortcut: $settingsManager.shortcutOpenHistory)
            }

            HStack {
                Text("検索フィールドにフォーカス")
                    .frame(width: 150, alignment: .leading)
                KeyRecorderView(shortcut: $settingsManager.shortcutFocusSearch)
            }

            Text("ショートカットを変更するには、ボタンをクリックしてキーを押してください。")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Notification Center

    private var notificationCenterSection: some View {
        Section("通知センター") {
            Toggle("保存後、通知センターから自動削除", isOn: $settingsManager.autoDeleteFromNotificationCenter)

            if settingsManager.autoDeleteFromNotificationCenter {
                Picker("削除タイミング", selection: $settingsManager.deleteDelay) {
                    ForEach(SettingsManager.DeleteDelay.allCases, id: \.self) { delay in
                        Text(delay.displayName).tag(delay)
                    }
                }
                .pickerStyle(.radioGroup)
                .padding(.leading, 20)
            }
        }
    }

    // MARK: - Hover Preview

    private var hoverPreviewSection: some View {
        Section("ホバープレビュー") {
            Picker("表示内容", selection: $settingsManager.hoverPreviewMode) {
                ForEach(SettingsManager.HoverPreviewMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.radioGroup)

            Divider()

            // サイズ設定
            VStack(alignment: .leading, spacing: 12) {
                Text("サイズ")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                // 幅
                HStack {
                    Text("幅:")
                        .frame(width: 60, alignment: .leading)
                    Slider(
                        value: $settingsManager.hoverPreviewWidth,
                        in: 200...1200,
                        step: 10
                    )
                    Text("\(Int(settingsManager.hoverPreviewWidth))px")
                        .frame(width: 60, alignment: .trailing)
                        .foregroundColor(.secondary)
                }

                // 高さ
                HStack {
                    Text("高さ:")
                        .frame(width: 60, alignment: .leading)
                    Slider(
                        value: $settingsManager.hoverPreviewHeight,
                        in: 150...500,
                        step: 10
                    )
                    Text("\(Int(settingsManager.hoverPreviewHeight))px")
                        .frame(width: 60, alignment: .trailing)
                        .foregroundColor(.secondary)
                }

                // 文字サイズ
                HStack {
                    Text("文字:")
                        .frame(width: 60, alignment: .leading)
                    Slider(
                        value: $settingsManager.hoverPreviewFontSize,
                        in: 8...30,
                        step: 1
                    )
                    Text("\(Int(settingsManager.hoverPreviewFontSize))pt")
                        .frame(width: 60, alignment: .trailing)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Dropdown

    private var dropdownSection: some View {
        Section("ドロップダウンメニュー") {
            VStack(alignment: .leading, spacing: 12) {
                Text("サイズ")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                // 幅
                HStack {
                    Text("幅:")
                        .frame(width: 60, alignment: .leading)
                    Slider(
                        value: $settingsManager.dropdownWidth,
                        in: 300...800,
                        step: 10
                    )
                    Text("\(Int(settingsManager.dropdownWidth))px")
                        .frame(width: 60, alignment: .trailing)
                        .foregroundColor(.secondary)
                }

                // 高さ
                HStack {
                    Text("高さ:")
                        .frame(width: 60, alignment: .leading)
                    Slider(
                        value: $settingsManager.dropdownHeight,
                        in: 400...800,
                        step: 10
                    )
                    Text("\(Int(settingsManager.dropdownHeight))px")
                        .frame(width: 60, alignment: .trailing)
                        .foregroundColor(.secondary)
                }

                // 文字サイズ
                HStack {
                    Text("文字:")
                        .frame(width: 60, alignment: .leading)
                    Slider(
                        value: $settingsManager.dropdownFontSize,
                        in: 8...30,
                        step: 1
                    )
                    Text("\(Int(settingsManager.dropdownFontSize))pt")
                        .frame(width: 60, alignment: .trailing)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Popup

    @ViewBuilder
    private var popupSection: some View {
        Section("カスタムポップアップ") {
            Toggle("ポップアップ通知を表示", isOn: $settingsManager.popupEnabled)

            if settingsManager.popupEnabled {
                // 表示時間
                HStack {
                    Text("表示時間:")
                    Stepper(
                        value: $settingsManager.popupDuration,
                        in: 0...30,
                        step: 1
                    ) {
                        Text(settingsManager.popupDuration == 0 ? "消えない" : "\(settingsManager.popupDuration)秒")
                            .frame(width: 60)
                    }
                }

                // 透過率
                HStack {
                    Text("透過率:")
                    Slider(value: $settingsManager.popupOpacity, in: 0.3...1.0, step: 0.05)
                    Text("\(Int(settingsManager.popupOpacity * 100))%")
                        .frame(width: 40)
                }

                // 文字サイズ
                HStack {
                    Text("文字サイズ:")
                    Slider(value: $settingsManager.popupFontSize, in: 10...30, step: 1)
                    Text("\(Int(settingsManager.popupFontSize))pt")
                        .frame(width: 40)
                }

                // サイズ（4K対応）
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("幅:")
                            .frame(width: 40, alignment: .leading)
                        Slider(value: $settingsManager.popupWidth, in: 200...1200, step: 10)
                        Text("\(Int(settingsManager.popupWidth))")
                            .frame(width: 50)
                    }
                    HStack {
                        Text("高さ:")
                            .frame(width: 40, alignment: .leading)
                        Slider(value: $settingsManager.popupHeight, in: 60...400, step: 10)
                        Text("\(Int(settingsManager.popupHeight))")
                            .frame(width: 50)
                    }
                }

                // 位置
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("X:")
                            .frame(width: 40, alignment: .leading)
                        Slider(value: $settingsManager.popupX, in: 0...maxScreenX, step: 10)
                        Text("\(Int(settingsManager.popupX))")
                            .frame(width: 50)
                    }
                    HStack {
                        Text("Y:")
                            .frame(width: 40, alignment: .leading)
                        Slider(value: $settingsManager.popupY, in: 0...maxScreenY, step: 10)
                        Text("\(Int(settingsManager.popupY))")
                            .frame(width: 50)
                    }
                }

                // テスト・プレビューボタン
                HStack {
                    Button("プレビュー表示") {
                        NotificationPopupController.shared.showPreview()
                    }

                    Button("テスト通知") {
                        sendTestNotification()
                    }
                }
            }
        }
    }

    // MARK: - Retention

    private var retentionSection: some View {
        Section("保存期間") {
            Picker("保存期間", selection: $settingsManager.retentionPeriod) {
                ForEach(SettingsManager.RetentionPeriod.allCases, id: \.self) { period in
                    Text(period.displayName).tag(period)
                }
            }
            .pickerStyle(.radioGroup)
        }
    }

    // MARK: - Excluded Apps

    private var excludedAppsSection: some View {
        Section("除外アプリ") {
            Text("通知を保存しないアプリ:")
                .font(.caption)
                .foregroundColor(.secondary)

            if settingsManager.excludedApps.isEmpty {
                Text("なし")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(settingsManager.excludedApps, id: \.self) { bundleId in
                    HStack {
                        Text(getAppName(for: bundleId))

                        Spacer()

                        Button(action: {
                            settingsManager.removeExcludedApp(bundleId)
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button(action: { showingAddAppSheet = true }) {
                Label("アプリを追加", systemImage: "plus")
            }
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        Section("データ") {
            HStack {
                Text("保存件数:")
                Spacer()
                Text("\(storageManager.storageInfo.count) 件")
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("ストレージ:")
                Spacer()
                Text(storageManager.storageInfo.sizeString)
                    .foregroundColor(.secondary)
            }

            HStack {
                Button("履歴をクリア") {
                    showingClearConfirmation = true
                }

                Spacer()

                Menu("エクスポート") {
                    Button("JSON形式") { exportJSON() }
                    Button("CSV形式") { exportCSV() }
                }
            }

            Divider()

            // 負荷テストボタン
            HStack {
                Button("負荷テスト (1000件)") {
                    showingLoadTestConfirmation = true
                }
                .help("テスト通知を1000件生成します")

                Spacer()

                if isLoadTestRunning {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            VStack(spacing: 12) {
                // アプリ名とバージョン
                VStack(spacing: 4) {
                    Text("NotifyDeck")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Version \(AppConstants.version)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)

                Divider()

                // GitHubリンク
                Button(action: {
                    NSWorkspace.shared.open(AppConstants.githubURL)
                }) {
                    HStack {
                        Image(systemName: "arrow.up.forward.square")
                        Text("GitHub リポジトリ")
                    }
                    .frame(maxWidth: .infinity)
                }

                // Buy Me a Coffeeボタン
                Button(action: {
                    NSWorkspace.shared.open(AppConstants.buyMeCoffeeURL)
                }) {
                    HStack {
                        Image(systemName: "cup.and.saucer.fill")
                        Text("Buy Me a Coffee")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Divider()

                // ライセンス情報
                VStack(alignment: .leading, spacing: 4) {
                    Text("ライセンス")
                        .font(.caption)
                        .fontWeight(.semibold)

                    Text(AppConstants.licenseText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Helper Methods

    private func runLoadTest() {
        isLoadTestRunning = true
        loadTestError = nil

        // バックグラウンドで実行
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try storageManager.generateTestNotifications(count: 1000)

                DispatchQueue.main.async {
                    isLoadTestRunning = false
                    loadTestCompleted = true
                }
            } catch {
                DispatchQueue.main.async {
                    isLoadTestRunning = false
                    loadTestError = error.localizedDescription
                    loadTestCompleted = true
                }
            }
        }
    }

    private func updateLoginItem(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Login item error: \(error)")
        }
    }

    private func getAppName(for bundleId: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
           let bundle = Bundle(url: url),
           let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String {
            return name
        }
        return bundleId
    }

    private func exportJSON() {
        guard let data = storageManager.exportAsJSON() else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "notifications.json"

        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url)
        }
    }

    private func exportCSV() {
        let csv = storageManager.exportAsCSV()

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "notifications.csv"

        if panel.runModal() == .OK, let url = panel.url {
            try? csv.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func sendTestNotification() {
        let testNotification = NotificationItem(
            appIdentifier: "com.mugendesk.NotifyDeck",
            appName: "NotifyDeck",
            title: "テスト通知",
            body: "これはテスト通知です。位置やサイズを確認してください。",
            timestamp: Date()
        )
        NotificationPopupController.shared.show(testNotification)
    }
}

// MARK: - Add Excluded App View

struct AddExcludedAppView: View {
    @ObservedObject var settingsManager: SettingsManager
    @Environment(\.dismiss) var dismiss

    @State private var runningApps: [(name: String, bundleId: String)] = []

    var body: some View {
        VStack(spacing: 0) {
            Text("除外するアプリを選択")
                .font(.headline)
                .padding()

            Divider()

            List(runningApps, id: \.bundleId) { app in
                Button(action: {
                    settingsManager.addExcludedApp(app.bundleId)
                    dismiss()
                }) {
                    HStack {
                        Text(app.name)
                        Spacer()
                        if settingsManager.isAppExcluded(app.bundleId) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .frame(height: 300)

            Divider()

            HStack {
                Spacer()
                Button("キャンセル") {
                    dismiss()
                }
            }
            .padding()
        }
        .frame(width: 350)
        .onAppear {
            loadRunningApps()
        }
    }

    private func loadRunningApps() {
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> (name: String, bundleId: String)? in
                guard let name = app.localizedName,
                      let bundleId = app.bundleIdentifier else { return nil }
                return (name, bundleId)
            }
            .sorted { $0.name < $1.name }

        runningApps = apps
    }
}

#Preview {
    SettingsView()
        .environmentObject(SettingsManager.shared)
        .environmentObject(StorageManager.shared)
}
