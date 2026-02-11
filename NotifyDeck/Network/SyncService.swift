import Foundation
import Combine

/// Magic Deck連携サービス
final class SyncService: ObservableObject {
    static let shared = SyncService()

    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession!
    private var pingTimer: Timer?

    private let storageManager = StorageManager.shared
    private var cancellables = Set<AnyCancellable>()

    @Published private(set) var isConnected = false
    @Published private(set) var connectedDeviceName: String?
    @Published private(set) var lastError: String?

    // サーバー設定
    private let port: UInt16 = 24801

    private init() {
        session = URLSession(configuration: .default)
        observeNotifications()
    }

    // MARK: - Connection

    /// Magic Deckに接続
    func connect(to host: String) {
        disconnect()

        let url = URL(string: "ws://\(host):\(port)/notify")!
        webSocketTask = session.webSocketTask(with: url)

        webSocketTask?.resume()
        receiveMessage()
        startPing()

        isConnected = true
        lastError = nil

        // 接続完了を送信
        sendMessage(.connected(deviceName: Host.current().localizedName ?? "Mac"))
    }

    /// 切断
    func disconnect() {
        pingTimer?.invalidate()
        pingTimer = nil

        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil

        isConnected = false
        connectedDeviceName = nil
    }

    // MARK: - Message Handling

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handleMessage(message)
                self?.receiveMessage()
            case .failure(let error):
                DispatchQueue.main.async {
                    self?.lastError = error.localizedDescription
                    self?.disconnect()
                }
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            if let data = text.data(using: .utf8),
               let msg = try? JSONDecoder().decode(SyncMessage.self, from: data) {
                DispatchQueue.main.async {
                    self.processMessage(msg)
                }
            }
        case .data(let data):
            if let msg = try? JSONDecoder().decode(SyncMessage.self, from: data) {
                DispatchQueue.main.async {
                    self.processMessage(msg)
                }
            }
        @unknown default:
            break
        }
    }

    private func processMessage(_ message: SyncMessage) {
        switch message.type {
        case .connected:
            connectedDeviceName = message.deviceName
        case .requestHistory:
            sendNotificationHistory()
        case .markAsRead:
            if let id = message.notificationId {
                try? storageManager.markAsRead(id)
            }
        case .ping:
            sendMessage(.pong)
        default:
            break
        }
    }

    // MARK: - Send Messages

    private func sendMessage(_ message: SyncMessage) {
        guard let data = try? JSONEncoder().encode(message),
              let text = String(data: data, encoding: .utf8) else { return }

        webSocketTask?.send(.string(text)) { error in
            if let error = error {
                print("SyncService send error: \(error)")
            }
        }
    }

    private func sendNotificationHistory() {
        let notifications = storageManager.fetchRecent(count: 100)
        let message = SyncMessage(
            type: .history,
            notifications: notifications
        )
        sendMessage(message)
    }

    private func sendNewNotification(_ notification: NotificationItem) {
        guard isConnected else { return }

        let message = SyncMessage(
            type: .newNotification,
            notifications: [notification]
        )
        sendMessage(message)
    }

    // MARK: - Ping/Pong

    private func startPing() {
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.sendMessage(.ping)
        }
    }

    // MARK: - Observe Notifications

    private func observeNotifications() {
        storageManager.$notifications
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] notifications in
                if let latest = notifications.first {
                    self?.sendNewNotification(latest)
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Sync Message

struct SyncMessage: Codable {
    enum MessageType: String, Codable {
        case connected
        case disconnected
        case ping
        case pong
        case requestHistory
        case history
        case newNotification
        case markAsRead
    }

    let type: MessageType
    var deviceName: String?
    var notificationId: String?
    var notifications: [NotificationItem]?

    static let ping = SyncMessage(type: .ping)
    static let pong = SyncMessage(type: .pong)

    static func connected(deviceName: String) -> SyncMessage {
        SyncMessage(type: .connected, deviceName: deviceName)
    }
}

// MARK: - Discovery

extension SyncService {
    /// ローカルネットワークでMagic Deckを探索
    func discoverDevices(completion: @escaping ([(name: String, host: String)]) -> Void) {
        // Bonjour/mDNSでMagic Deckを探索
        // TODO: NetServiceBrowserを使用した実装

        // 暫定実装：既知のホストを返す
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            completion([])
        }
    }
}
