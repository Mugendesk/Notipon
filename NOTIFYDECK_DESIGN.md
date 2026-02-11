# NotifyDeck 仕様書

macOS通知センターの履歴を保存・管理するメニューバーアプリケーション

## バージョン情報
- **バージョン**: 1.0.0
- **最終更新**: 2026-01-08
- **対応OS**: macOS 13.0以上

---

## 概要

NotifyDeckは、macOS通知センターの通知を自動的に保存し、検索・管理できるメニューバーアプリです。

### 主な機能
- ✅ macOS通知の自動保存（Accessibility API使用）
- ✅ リアルタイム通知検知（50msポーリング）
- ✅ メニューバーからの通知閲覧
- ✅ カスタムポップアップ通知
- ✅ 通知履歴の検索・フィルタリング
- ✅ アプリごとの除外設定
- ✅ JSON/CSVエクスポート
- ✅ 自動起動設定

---

## アーキテクチャ

### プロジェクト構造
```
NotifyDeck/
├── NotifyDeck.xcodeproj/
├── NotifyDeck/
│   ├── NotifyDeckApp.swift          # エントリーポイント
│   ├── Info.plist
│   ├── NotifyDeck.entitlements
│   │
│   ├── Core/
│   │   ├── AccessibilityNotificationObserver.swift  # リアルタイム通知検知
│   │   ├── NotificationMonitor.swift                # 通知DB監視（フォールバック）
│   │   ├── StorageManager.swift                     # ローカルSQLite (GRDB)
│   │   ├── NotificationCleaner.swift                # 通知センター自動削除
│   │   ├── PermissionManager.swift                  # 権限管理
│   │   └── SettingsManager.swift                    # 設定管理
│   │
│   ├── Models/
│   │   ├── NotificationItem.swift      # 通知データモデル
│   │   └── NotificationFilter.swift    # フィルタ条件
│   │
│   ├── UI/
│   │   ├── MenuBarController.swift           # NSStatusItem + ホバー検知
│   │   ├── HoverPreviewView.swift            # ホバープレビュー (直近5件)
│   │   ├── DropdownView.swift                # ドロップダウンUI (20件)
│   │   ├── HistoryWindowView.swift           # 履歴ウィンドウ (全画面)
│   │   ├── SettingsView.swift                # 設定画面
│   │   ├── NotificationPopupController.swift # カスタムポップアップ
│   │   ├── NotificationPopupView.swift       # ポップアップUI
│   │   └── Components/
│   │       ├── NotificationRow.swift   # 通知行コンポーネント
│   │       ├── AppFilterChip.swift     # アプリフィルタ
│   │       └── SearchBar.swift         # 検索バー
│   │
│   └── Resources/
│       └── Assets.xcassets/
│           └── AppIcon.appiconset/     # Discord風の青白アイコン
```

---

## 技術仕様

### 1. 通知検知システム

#### Accessibility API（メイン）
- **ファイル**: `AccessibilityNotificationObserver.swift`
- **検知方法**: NotificationCenterUIプロセスを50msポーリング
- **遅延**: 平均25-50ms
- **特徴**:
  - ウィンドウの位置・サイズで通知バナーを判定
  - 通知センター開封時の誤検知を防止（重複チェック）
  - AXObserverのフォールバック併用

```swift
// 通知バナーの判定条件
let isSmallHeight = size.height < 200
let isTopPosition = position.y > screenHeight - 200
let isRightSide = position.x > screenWidth - 600
```

#### 通知DB監視（フォールバック）
- **ファイル**: `NotificationMonitor.swift`
- **監視対象**: `~/Library/Group Containers/group.com.apple.usernoted/db2/db`
- **検知方法**: SQLite直接読み取り + ポーリング
- **遅延**: 最大2秒

### 2. データストレージ

#### ローカルDB (GRDB)
- **ファイル**: `StorageManager.swift`
- **DB場所**: `~/Library/Application Support/NotifyDeck/notifications.db`
- **スキーマ**:
```sql
CREATE TABLE notifications (
    id TEXT PRIMARY KEY,
    app_identifier TEXT NOT NULL,
    app_name TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    subtitle TEXT,
    timestamp DATETIME NOT NULL,
    is_read BOOLEAN NOT NULL DEFAULT 0,
    thread_identifier TEXT,
    category_identifier TEXT,
    image_data BLOB
);

CREATE INDEX idx_notifications_timestamp ON notifications(timestamp);
CREATE INDEX idx_notifications_app ON notifications(app_identifier);
```

#### パフォーマンス最適化
- **アプリアイコンキャッシュ**: スレッドセーフな`AppIconCache`でNSImageをキャッシュ
- **メモリフィルタリング**: DBクエリを減らし、メモリ上でフィルタリング（高速化）
- **既読・削除は即時反映**: `@Published`でリアクティブ更新

### 3. UI設計

#### メニューバーアイコン
- **表示**: 白色ベルアイコン（固定色、テーマ非依存）
- **未読バッジ**: 赤い丸 + 未読数表示（9件まで）

#### ホバープレビュー
- **トリガー**: メニューバーアイコンにマウスホバー（0.3秒遅延）
- **表示**: 直近5件 or 未読5件
- **動作**:
  - クリック → 既読
  - 右クリック → コンテキストメニュー（アプリ開く/既読/削除）

#### ドロップダウン
- **トリガー**: メニューバーアイコンをクリック
- **表示**: 直近20件
- **機能**: 全履歴を開く、設定を開く、すべて既読
- **動作**: ホバープレビューと同じ

#### 履歴ウィンドウ
- **トリガー**: メニューバーアイコンを右クリック
- **レイアウト**:
  - 左サイドバー: アプリフィルタ（実際のアプリアイコン表示）
  - メインエリア: 日付グループ化された通知一覧
- **機能**:
  - 検索（タイトル・本文・アプリ名）
  - アプリ別フィルタ（単一選択）
  - 全削除・個別削除
  - すべて既読
  - エクスポート（JSON/CSV）
- **パフォーマンス**: メモリフィルタリングで高速切り替え

#### カスタムポップアップ
- **表示条件**: 設定で有効化時
- **カスタマイズ可能項目**:
  - 表示時間（0-30秒、0=消えない）
  - 透過率（30-100%）
  - 文字サイズ（10-30pt）
  - サイズ（幅200-1200px、高さ60-400px）
  - 位置（X/Y座標）
- **特徴**: アプリアイコン表示、画像表示対応

### 4. 設定管理

#### UserDefaults保存項目
- 自動起動設定
- 未読バッジ表示
- 通知センター自動削除（即時/1秒後/2秒後）
- ホバープレビューモード（直近5件/未読のみ）
- ポップアップ設定（有効/無効、カスタマイズ）
- 保存期間（1週間/1ヶ月/3ヶ月/6ヶ月/1年/無制限）
- 除外アプリリスト

---

## 必要な権限

### 1. フルディスクアクセス
- **用途**: 通知DB読み取り（`~/Library/Group Containers/`）
- **設定**: システム設定 → プライバシーとセキュリティ → フルディスクアクセス

### 2. アクセシビリティ
- **用途**: リアルタイム通知検知（NotificationCenterUI監視）
- **設定**: システム設定 → プライバシーとセキュリティ → アクセシビリティ

---

## 配布方法

### 署名なし配布（現状）
- **ターゲット**: オープンソースコミュニティ
- **起動方法**: 右クリック → 「開く」
- **メリット**: 無料、開発者情報非公開

### 署名付き配布（将来）
- **必要なもの**: Apple Developer Program（年間$99）+ 個人事業主登録
- **署名**: Developer ID Application
- **公証**: Apple公証サービス
- **メリット**: ダブルクリックで起動可能

---

## パフォーマンス指標

| 項目 | 性能 |
|------|------|
| 通知検知遅延 | 平均25-50ms |
| アプリフィルタ切り替え | 即時（メモリフィルタ） |
| アイコン読み込み | キャッシュ済み即時 / 初回100ms以下 |
| 検索レスポンス | 即時（メモリフィルタ） |
| CPU使用率 | アイドル時0.1%未満 |

---

## 既知の制限事項

1. **通知DBのPrivate API依存**
   - macOSアップデートで仕様変更の可能性
   - 現在動作確認済み: macOS 13.0 - 15.x

2. **アプリアイコン取得**
   - アンインストール済みアプリのアイコンは表示不可
   - フォールバック: SF Symbolsアイコン

3. **通知センター削除**
   - AppleScript経由（ベストエフォート）
   - 失敗してもエラー通知なし

---

## 今後の拡張予定

- [ ] iCloud同期（他のMacと通知履歴を共有）
- [ ] Shortcuts.app連携
- [ ] 通知の統計表示（アプリ別グラフなど）
- [ ] カスタムフィルタルール
- [ ] タグ付け機能

---

## 開発情報

### ビルド方法
```bash
# Releaseビルド
xcodebuild -scheme NotifyDeck -configuration Release \
  -derivedDataPath ./build build

# 署名なし配布用パッケージ作成
cd build/Build/Products/Release
zip -r NotifyDeck.zip NotifyDeck.app
```

### 依存ライブラリ
- **GRDB.swift** (6.29.3): SQLiteラッパー

### 必要なEntitlements
```xml
<key>com.apple.security.automation.apple-events</key>
<true/>
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
```

---

## ライセンス
MIT License

## 作者
Mugendesk

## リポジトリ
https://github.com/Mutafika/Mugendesk
