import Foundation
import SwiftUI
import os.log

class LoggerManager: ObservableObject {
    static let shared = LoggerManager()
    
    @Published var logs: [LogEntry] = []
    @Published var isEnabled: Bool = true
    @Published var maxLogs: Int = 1000
    
    private let logger = OSLog(subsystem: "com.myclash.MyClash", category: "Logger")
    private let maxLogsLimit: Int
    private var fileURL: URL?
    
    private init() {
        maxLogsLimit = maxLogs
        setupLogFile()
    }
    
    func setupLogFile() {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }
        
        let directory = appSupport.appendingPathComponent("MyClash")
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        let logFile = directory.appendingPathComponent("logs/\(dateString).log")
        fileURL = logFile
    }
    
    func log(_ message: String, level: LogLevel = .info, category: String = "App") {
        guard isEnabled else { return }
        
        let entry = LogEntry(message: message, level: level, category: category)
        
        DispatchQueue.main.async {
            self.logs.append(entry)
            if self.logs.count > self.maxLogsLimit {
                self.logs.removeFirst(self.logs.count - self.maxLogsLimit)
            }
        }
        
        // Log to OS log
        switch level {
        case .debug:
            os_log("%{public}@ - %{public}@", log: logger, type: .debug, category, message)
        case .info:
            os_log("%{public}@ - %{public}@", log: logger, type: .info, category, message)
        case .warning:
            os_log("%{public}@ - %{public}@", log: logger, type: .default, category, message)
        case .error:
            os_log("%{public}@ - %{public}@", log: logger, type: .error, category, message)
        }
        
        // Log to file
        writeToFile(entry)
    }
    
    private func writeToFile(_ entry: LogEntry) {
        guard let fileURL = fileURL else { return }
        
        let logString = "[\(entry.timestamp.formatted(date: .numeric, time: .standard))] [\(entry.level.rawValue)] \n[\(entry.category)] \(entry.message)\n\n"
        let data = logString.data(using: .utf8) ?? Data()
        
        if !FileManager.default.fileExists(atPath: fileURL.deletingLastPathComponent().path) {
            try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        }
        
        if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
            try? fileHandle.seekToEnd()
            fileHandle.write(data)
            try? fileHandle.close()
        } else {
            try? data.write(to: fileURL, options: .atomicWrite)
        }
    }
    
    func clearLogs() {
        logs.removeAll()
        log("Logs cleared", level: .info, category: "System")
    }
    
    func exportLogs() -> String {
        return logs.map { "\($0.timestamp.formatted(date: .numeric, time: .standard)) [$\($0.level.rawValue)] [$\($0.category)] $\($0.message)" }.joined(separator: "\n")
    }
    
    func searchLogs(query: String) -> [LogEntry] {
        return logs.filter { $0.message.lowercased().contains(query.lowercased()) }
    }
}

struct LogEntry: Identifiable {
    let id = UUID()
    let message: String
    let level: LogLevel
    let category: String
    let timestamp: Date
    
    init(message: String, level: LogLevel = .info, category: String = "App", timestamp: Date = Date()) {
        self.message = message
        self.level = level
        self.category = category
        self.timestamp = timestamp
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
}

enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
    
    var color: Color {
        switch self {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }
}
