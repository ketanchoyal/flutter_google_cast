import Foundation
#if canImport(Flutter)
import Flutter
#elseif canImport(FlutterMacOS)
import FlutterMacOS
#endif

/// Thread-safe logger and buffer for Google Cast SDK discovery and diagnostic events.
/// Forwards diagnostic events to Flutter via the method channel.
public final class CastLogger {
    public static let shared = CastLogger()
    private init() {}

    private let queue = DispatchQueue(label: "com.felnanuke.google_cast.logger")
    private var buffer: [String] = []
    private let maxBuffer = 150

    public func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "[\(timestamp)] [CastNative] \(message)"
        print(entry)

        queue.async {
            self.buffer.append(entry)
            if self.buffer.count > self.maxBuffer {
                self.buffer.removeFirst(self.buffer.count - self.maxBuffer)
            }
        }

        DispatchQueue.main.async {
            FGCDiscoveryManagerMethodChannel.instance.channel?.invokeMethod("onNativeLog", arguments: entry)
        }
    }

    public func getRecentLogs() -> [String] {
        return queue.sync { buffer }
    }
}
