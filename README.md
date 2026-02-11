# NotifyDeck

> A [Mugendesk](https://github.com/Mutafika/Mugendesk) Project

macOS通知センターの履歴を自動保存・管理するメニューバーアプリケーション

![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

## 📖 概要

NotifyDeckは、macOSの通知センターに表示された通知を自動的に保存し、後から検索・閲覧できるメニューバーアプリです。通知センターから消えてしまった重要な通知も、いつでも履歴から確認できます。

### 主な機能

- ✅ **リアルタイム通知保存** - macOSの通知を自動的に保存（平均25-50ms遅延）
- ✅ **メニューバーアクセス** - ホバーで直近5件をプレビュー、クリックで全履歴表示
- ✅ **強力な検索機能** - タイトル、本文、アプリ名で検索
- ✅ **アプリ別フィルタ** - 特定アプリの通知のみ表示
- ✅ **日付グループ化** - 「今日」「昨日」「M月d日」で自動整理
- ✅ **エクスポート** - JSON/CSV形式で書き出し
- ✅ **自動削除** - 保存後に通知センターから削除（オプション）
- ✅ **カスタムポップアップ** - 通知の表示位置・サイズをカスタマイズ
- ✅ **除外アプリ設定** - 特定アプリの通知を保存しない
- ✅ **自動起動** - ログイン時に自動起動

## 📸 スクリーンショット

### メニューバー
<img width="300" alt="メニューバー" src="docs/screenshots/menubar.png">

### 履歴ウィンドウ
<img width="700" alt="履歴ウィンドウ" src="docs/screenshots/history.png">

### 設定画面
<img width="480" alt="設定画面" src="docs/screenshots/settings.png">

## 🚀 インストール

### 必要要件

- macOS 13.0 (Ventura) 以降
- 約10MB以上の空き容量

### ダウンロード

1. [最新リリース](https://github.com/Mutafika/Mugendesk/releases/latest)から`NotifyDeck.zip`をダウンロード
2. ZIPファイルを解凍
3. `NotifyDeck.app`を`/Applications`フォルダに移動
4. アプリを起動（初回は右クリック→「開く」）

### 署名について

現在、このアプリは署名されていないため、初回起動時に以下の手順が必要です：

1. `NotifyDeck.app`を**右クリック**
2. **「開く」**を選択
3. 警告ダイアログで**「開く」**をクリック

## 🔐 必要な権限

NotifyDeckが動作するには、以下の権限が必要です：

### 1. フルディスクアクセス（必須）

macOSの通知データベースを読み取るために必要です。

**設定方法：**
1. `システム設定` → `プライバシーとセキュリティ` → `フルディスクアクセス`
2. 左下の🔒をクリックして認証
3. `+`ボタンをクリック
4. `/Applications/NotifyDeck.app`を選択
5. NotifyDeckを再起動

### 2. アクセシビリティ（推奨）

リアルタイム通知検知のために推奨します（なくても動作しますが、遅延が発生します）。

**設定方法：**
1. `システム設定` → `プライバシーとセキュリティ` → `アクセシビリティ`
2. 左下の🔒をクリックして認証
3. `+`ボタンをクリック
4. `/Applications/NotifyDeck.app`を選択
5. NotifyDeckを再起動

## 💡 使い方

### 基本操作

#### メニューバーアイコン
- **ホバー** - 直近5件（または未読5件）をプレビュー
- **クリック** - ドロップダウンメニュー表示
- **右クリック** - 履歴ウィンドウを開く

#### 通知の操作
- **クリック** - 既読にする
- **右クリック** - コンテキストメニュー（アプリを開く/既読/削除）

### 検索

履歴ウィンドウの検索バーで、以下を検索できます：
- タイトル
- 本文
- アプリ名

### フィルタリング

左サイドバーからアプリを選択すると、そのアプリの通知のみ表示されます。

### エクスポート

履歴ウィンドウの「エクスポート」メニューから、以下の形式で書き出せます：
- **JSON形式** - プログラムでの処理に適しています
- **CSV形式** - ExcelやGoogleスプレッドシートで開けます

## ⚙️ 設定

### 一般
- ログイン時に起動
- メニューバーに未読バッジを表示

### 通知センター
- 保存後、通知センターから自動削除
- 削除タイミング（即時/1秒後/2秒後）

### ホバープレビュー
- 直近5件を表示
- 未読のみ表示

### カスタムポップアップ
- ポップアップ通知の表示/非表示
- 表示時間（0-30秒、0=消えない）
- 透過率（30-100%）
- 文字サイズ（10-30pt）
- サイズ（幅200-1200px、高さ60-400px）
- 位置（X/Y座標）

### 保存期間
- 1週間
- 1ヶ月
- 3ヶ月
- 6ヶ月
- 1年
- 無制限

### 除外アプリ
通知を保存しないアプリを設定できます。

## 🛠 技術仕様

### アーキテクチャ
- **言語**: Swift 5.9
- **フレームワーク**: SwiftUI, AppKit
- **データベース**: SQLite (GRDB.swift)
- **通知検知**: Accessibility API（50msポーリング）

### パフォーマンス
| 項目 | 性能 |
|------|------|
| 通知検知遅延 | 平均25-50ms |
| アプリフィルタ切り替え | 即時（メモリフィルタ） |
| アイコン読み込み | キャッシュ済み即時 / 初回100ms以下 |
| CPU使用率 | アイドル時0.1%未満 |

### データ保存場所
```
~/Library/Application Support/NotifyDeck/notifications.db
```

## 🐛 トラブルシューティング

### 通知が保存されない

1. **フルディスクアクセス権限**を確認してください
2. NotifyDeckを再起動してください
3. ターミナルで以下を実行して、データベースが作成されているか確認：
   ```bash
   ls ~/Library/Application\ Support/NotifyDeck/
   ```

### 検知が遅い

1. **アクセシビリティ権限**を追加してください
2. リアルタイム検知が有効になり、遅延が改善されます

### アプリが起動しない

1. 右クリック→「開く」で起動してください
2. macOS 13.0以降が必要です
3. コンソールアプリでエラーログを確認してください

## 🤝 コントリビューション

プルリクエストを歓迎します！以下の手順で開発環境をセットアップできます：

```bash
git clone https://github.com/Mutafika/Mugendesk.git
cd Mugendesk/NotifyDeck
open NotifyDeck.xcodeproj
```

### 開発要件
- Xcode 15.0以降
- Swift 5.9以降

## 📄 ライセンス

MIT License

Copyright (c) 2026 Mugendesk

詳細は[LICENSE](LICENSE)ファイルをご覧ください。

## 🔗 リンク

- [GitHub リポジトリ](https://github.com/Mutafika/Mugendesk)
- [問題報告](https://github.com/Mutafika/Mugendesk/issues)
- [最新リリース](https://github.com/Mutafika/Mugendesk/releases)

## ☕ サポート

このプロジェクトが役に立ったら、ぜひ支援をお願いします！

[Buy Me a Coffee](https://example.com/donate)

---

Made with ❤️ by [Mugendesk](https://github.com/Mutafika/Mugendesk)
