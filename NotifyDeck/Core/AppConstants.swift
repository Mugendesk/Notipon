import Foundation

/// アプリ全体の定数管理
enum AppConstants {
    // MARK: - Version

    /// アプリバージョン（Info.plistから自動取得）
    static let version: String = {
        guard let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            return "1.0.0"
        }
        return version
    }()

    /// ビルド番号
    static let buildNumber: String = {
        guard let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String else {
            return "1"
        }
        return build
    }()

    /// バージョン文字列（フルバージョン）
    static var fullVersion: String {
        "\(version) (Build \(buildNumber))"
    }

    // MARK: - URLs

    static let githubURL = URL(string: "https://github.com/Mutafika/Mugendesk")!
    static let buyMeCoffeeURL = URL(string: "https://example.com/donate")!  // 仮URL（後で変更可能）
    static let versionCheckURL = URL(string: "https://mutafika.github.io/Mugendesk/notifydeck/version.json")!
    static let updateDownloadURL = URL(string: "https://github.com/Mutafika/Mugendesk/releases/latest")!

    // MARK: - License

    static let licenseText = """
    MIT License
    Copyright (c) 2026 Mugendesk
    詳細はGitHubリポジトリをご覧ください。
    """

    // MARK: - Test Data

    /// 負荷テスト用のアプリ定義
    static let testApps: [(identifier: String, name: String)] = [
        ("com.tinyspeck.slackmacgap", "Slack"),
        ("com.apple.mail", "Mail"),
        ("com.hnc.Discord", "Discord"),
        ("com.apple.iCal", "Calendar"),
        ("com.apple.MobileSMS", "Messages"),
        ("com.apple.Safari", "Safari"),
        ("com.spotify.client", "Spotify"),
        ("com.notion.app", "Notion"),
        ("com.figma.Desktop", "Figma"),
        ("com.microsoft.VSCode", "Visual Studio Code")
    ]

    /// テスト通知のタイトル候補
    static let testTitles = [
        "新しいメッセージ",
        "会議のリマインダー",
        "タスクの期限",
        "システム通知",
        "アップデート通知",
        "ファイルのダウンロード完了",
        "メンション",
        "新しいコメント",
        "承認リクエスト",
        "配信通知"
    ]

    /// テスト通知の本文候補
    static let testBodies = [
        "これはテスト通知です。",
        "負荷テスト用のダミーデータです。",
        "通知の表示と保存が正常に動作しているか確認してください。",
        "ストレージとパフォーマンスのテストに使用されます。",
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
        "このメッセージは自動生成されたテストデータです。",
        "1000件のテスト通知が作成されます。",
        "データベースの動作確認用です。",
        "フィルタリングと検索機能のテストにも使用できます。",
        "問題があれば「履歴をクリア」から削除できます。"
    ]
}
