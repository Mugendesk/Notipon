# NotifyDeck

> A [Mugendesk](https://github.com/Mutafika/Mugendesk) Project

A menu bar app that automatically saves and manages your macOS Notification Center history

![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

## 📖 Overview

NotifyDeck is a macOS menu bar application that automatically saves notifications from the Notification Center, allowing you to search and review them later. Never lose important notifications that disappear from the Notification Center again.

### Key Features

- ✅ **Real-time Notification Capture** - Automatically saves macOS notifications (25-50ms average latency)
- ✅ **Menu Bar Access** - Hover to preview 5 recent notifications, click for full history
- ✅ **Powerful Search** - Search by title, body, or app name
- ✅ **App Filtering** - Filter notifications by specific apps
- ✅ **Date Grouping** - Auto-organizes by "Today", "Yesterday", "Month/Day"
- ✅ **Export** - Export to JSON/CSV formats
- ✅ **Auto Cleanup** - Optionally remove notifications from Notification Center after saving
- ✅ **Custom Popup** - Customize notification position, size, and appearance
- ✅ **Exclude Apps** - Prevent specific apps from being saved
- ✅ **Auto Launch** - Launch at login

## 📸 Screenshots

### Menu Bar
<img width="300" alt="Menu Bar" src="docs/screenshots/menubar.png">

### History Window
<img width="700" alt="History Window" src="docs/screenshots/history.png">

### Settings
<img width="480" alt="Settings" src="docs/screenshots/settings.png">

## 🚀 Installation

### Requirements

- macOS 13.0 (Ventura) or later
- ~10MB free disk space

### Download

1. Download `NotifyDeck.zip` from the [latest release](https://github.com/Mutafika/Mugendesk/releases/latest)
2. Extract the ZIP file
3. Move `NotifyDeck.app` to `/Applications` folder
4. Launch the app (first time: right-click → "Open")

### Code Signing

This app is currently unsigned. For first launch:

1. **Right-click** on `NotifyDeck.app`
2. Select **"Open"**
3. Click **"Open"** in the warning dialog

## 🔐 Required Permissions

NotifyDeck requires the following permissions to function:

### 1. Full Disk Access (Required)

Necessary to read macOS notification database.

**Setup:**
1. `System Settings` → `Privacy & Security` → `Full Disk Access`
2. Click 🔒 to authenticate
3. Click `+` button
4. Select `/Applications/NotifyDeck.app`
5. Restart NotifyDeck

### 2. Accessibility (Recommended)

Recommended for real-time notification detection (works without it, but with higher latency).

**Setup:**
1. `System Settings` → `Privacy & Security` → `Accessibility`
2. Click 🔒 to authenticate
3. Click `+` button
4. Select `/Applications/NotifyDeck.app`
5. Restart NotifyDeck

## 💡 Usage

### Basic Operations

#### Menu Bar Icon
- **Hover** - Preview 5 recent notifications (or 5 unread)
- **Click** - Show dropdown menu
- **Right-click** - Open history window

#### Notification Actions
- **Click** - Mark as read
- **Right-click** - Context menu (Open app / Mark as read / Delete)

### Search

Use the search bar in the history window to search:
- Title
- Body
- App name

### Filtering

Select an app from the left sidebar to show only notifications from that app.

### Export

From the "Export" menu in the history window, export in:
- **JSON format** - Ideal for programmatic processing
- **CSV format** - Can be opened in Excel or Google Sheets

## ⚙️ Settings

### General
- Launch at login
- Show unread badge in menu bar

### Notification Center
- Auto-remove from Notification Center after saving
- Removal timing (Immediately / After 5 seconds / After 1 minute)

### Hover Preview
- Show 5 recent notifications
- Show unread only

### Custom Popup
- Enable/disable popup notifications
- Display duration (0-30 seconds, 0 = persistent)
- Opacity (30-100%)
- Font size (10-30pt)
- Size (Width 200-1200px, Height 60-400px)
- Position (X/Y coordinates)

### Retention Period
- 24 hours
- 7 days
- 30 days
- Unlimited

### Excluded Apps
Configure apps whose notifications should not be saved.

## 🛠 Technical Specifications

### Architecture
- **Language**: Swift 5.9
- **Frameworks**: SwiftUI, AppKit
- **Database**: SQLite (GRDB.swift)
- **Notification Detection**: Accessibility API (50ms polling)

### Performance
| Metric | Performance |
|--------|------------|
| Notification detection latency | Average 25-50ms |
| App filter switching | Instant (in-memory filter) |
| Icon loading | Instant (cached) / <100ms (first time) |
| CPU usage | <0.1% when idle |

### Data Storage Location
```
~/Library/Application Support/NotifyDeck/notifications.db
```

## 🐛 Troubleshooting

### Notifications not being saved

1. Verify **Full Disk Access** permission is granted
2. Restart NotifyDeck
3. Check if database exists:
   ```bash
   ls ~/Library/Application\ Support/NotifyDeck/
   ```

### Slow detection

1. Add **Accessibility** permission
2. Real-time detection will be enabled, reducing latency

### App won't launch

1. Right-click → "Open" to launch
2. Requires macOS 13.0 or later
3. Check Console.app for error logs

## 🤝 Contributing

Pull requests are welcome! Set up the development environment:

```bash
git clone https://github.com/Mutafika/Mugendesk.git
cd Mugendesk/NotifyDeck
open NotifyDeck.xcodeproj
```

### Development Requirements
- Xcode 15.0 or later
- Swift 5.9 or later

## 📄 License

MIT License

Copyright (c) 2026 Mutafika

See [LICENSE](LICENSE) file for details.

## 🔗 Links

- [GitHub Repository](https://github.com/Mutafika/Mugendesk)
- [Report Issues](https://github.com/Mutafika/Mugendesk/issues)
- [Latest Release](https://github.com/Mutafika/Mugendesk/releases)

## ☕ Support

If you find this project helpful, please consider supporting it!

[Buy Me a Coffee](https://example.com/donate)

---

Made with ❤️ by [Mugendesk](https://github.com/Mutafika/Mugendesk)
