import Foundation
import AppKit

/// バージョンチェック機能
final class VersionChecker {
    static let shared = VersionChecker()

    private init() {}

    // MARK: - Version Check

    /// 最新バージョンをチェック
    /// - Parameter completion: チェック完了時のコールバック
    func checkForUpdates(completion: ((Result<VersionInfo, Error>) -> Void)? = nil) {
        guard let url = URL(string: AppConstants.versionCheckURL.absoluteString) else {
            completion?(.failure(VersionCheckError.invalidURL))
            return
        }

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            // エラーハンドリング
            if let error = error {
                print("Version check failed: \(error)")
                completion?(.failure(error))
                return
            }

            guard let data = data else {
                completion?(.failure(VersionCheckError.noData))
                return
            }

            // JSONデコード
            do {
                let versionInfo = try JSONDecoder().decode(VersionInfo.self, from: data)

                // バージョン比較
                if self.isNewerVersion(versionInfo.version, than: AppConstants.version) {
                    // メインスレッドでアラート表示
                    DispatchQueue.main.async {
                        self.showUpdateAlert(versionInfo: versionInfo)
                    }
                    completion?(.success(versionInfo))
                } else {
                    print("Already up to date: \(AppConstants.version)")
                    completion?(.success(versionInfo))
                }
            } catch {
                print("Version check decode error: \(error)")
                completion?(.failure(error))
            }
        }

        task.resume()
    }

    // MARK: - Version Comparison

    /// バージョン番号を比較（セマンティックバージョニング）
    /// - Parameters:
    ///   - newVersion: 新しいバージョン（例: "1.0.1"）
    ///   - currentVersion: 現在のバージョン（例: "1.0.0"）
    /// - Returns: newVersionが新しい場合true
    private func isNewerVersion(_ newVersion: String, than currentVersion: String) -> Bool {
        let newComponents = newVersion.split(separator: ".").compactMap { Int($0) }
        let currentComponents = currentVersion.split(separator: ".").compactMap { Int($0) }

        // 各桁を比較（Major.Minor.Patch）
        for i in 0..<max(newComponents.count, currentComponents.count) {
            let new = i < newComponents.count ? newComponents[i] : 0
            let current = i < currentComponents.count ? currentComponents[i] : 0

            if new > current {
                return true
            } else if new < current {
                return false
            }
        }

        return false
    }

    // MARK: - Alert

    /// アップデート通知アラートを表示
    private func showUpdateAlert(versionInfo: VersionInfo) {
        let alert = NSAlert()
        alert.messageText = "新しいバージョンが利用可能です"
        alert.informativeText = """
        NotifyDeck v\(versionInfo.version) がリリースされました。

        現在のバージョン: \(AppConstants.version)
        最新バージョン: \(versionInfo.version)

        リリースノート:
        \(versionInfo.releaseNotes["ja"] ?? versionInfo.releaseNotes["en"] ?? "")
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "アップデート")
        alert.addButton(withTitle: "後で")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            // アップデートボタンが押された
            if let url = URL(string: versionInfo.downloadURL) {
                NSWorkspace.shared.open(url)
            } else {
                // フォールバック: GitHub Releasesへ
                NSWorkspace.shared.open(AppConstants.updateDownloadURL)
            }
        }
    }
}

// MARK: - Models

/// バージョン情報
struct VersionInfo: Codable {
    let version: String
    let releaseDate: String
    let downloadURL: String
    let releaseNotes: [String: String]
    let minimumMacOSVersion: String
}

/// バージョンチェックエラー
enum VersionCheckError: LocalizedError {
    case invalidURL
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "無効なURLです"
        case .noData:
            return "データを取得できませんでした"
        }
    }
}
