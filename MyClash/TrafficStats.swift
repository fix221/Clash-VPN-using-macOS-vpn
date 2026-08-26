import Foundation
import SwiftUI
import Combine

class TrafficStats: ObservableObject {
    static let shared = TrafficStats()
    
    @Published var uploadSpeed: Double = 0
    @Published var downloadSpeed: Double = 0
    @Published var totalUpload: UInt64 = 0
    @Published var totalDownload: UInt64 = 0
    @Published var uploadPeak: Double = 0
    @Published var downloadPeak: Double = 0
    @Published var isTracking: Bool = false
    
    private var lastBytesRead: UInt64 = 0
    private var lastBytesWritten: UInt64 = 0
    private var lastUpdateTime: Date = Date()
    private var timer: Timer?
    private var speedHistory: [(timestamp: Date, uploadSpeed: Double, downloadSpeed: Double)] = []
    private let maxHistoryPoints = 60
    
    private init() {
        setupTracking()
    }
    
    private func setupTracking() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateStats()
        }
    }
    
    func startTracking() {
        guard !isTracking else { return }
        isTracking = true
        lastBytesRead = 0
        lastBytesWritten = 0
        lastUpdateTime = Date()
        setupTracking()
    }
    
    func stopTracking() {
        isTracking = false
        timer?.invalidate()
        timer = nil
        uploadSpeed = 0
        downloadSpeed = 0
    }
    
    private func updateStats() {
        VPNManager.shared.sendAppMessage("getStatus") { [weak self] responseData in
            guard let responseData = responseData,
                  let dict = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
                return
            }
            
            DispatchQueue.main.async {
                if let bytesRead = dict["bytesRead"] as? UInt64,
                   let bytesWritten = dict["bytesWritten"] as? UInt64 {
                    self.updateTraffic(bytesRead: bytesRead, bytesWritten: bytesWritten)
                }
            }
        }
    }
    
    func updateTraffic(bytesRead: UInt64, bytesWritten: UInt64) {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastUpdateTime)
        
        if elapsed > 0 {
            let currentDownloadSpeed = Double(bytesRead - lastBytesRead) / elapsed
            let currentUploadSpeed = Double(bytesWritten - lastBytesWritten) / elapsed
            
            DispatchQueue.main.async {
                self.downloadSpeed = currentDownloadSpeed
                self.uploadSpeed = currentUploadSpeed
                self.totalDownload = bytesRead
                self.totalUpload = bytesWritten
                
                if currentDownloadSpeed > self.downloadPeak {
                    self.downloadPeak = currentDownloadSpeed
                }
                if currentUploadSpeed > self.uploadPeak {
                    self.uploadPeak = currentUploadSpeed
                }
                
                self.speedHistory.append((timestamp: now, uploadSpeed: currentUploadSpeed, downloadSpeed: currentDownloadSpeed))
                if self.speedHistory.count > self.maxHistoryPoints {
                    self.speedHistory.removeFirst()
                }
            }
        }
        
        lastBytesRead = bytesRead
        lastBytesWritten = bytesWritten
        lastUpdateTime = now
    }
    
    func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    func formatSpeed(_ bytesPerSecond: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        formatter.includesUnit = true
        let string = formatter.string(fromByteCount: Int64(bytesPerSecond))
        return (string ?? "0 B") + "/s"
    }
    
    func resetPeaks() {
        uploadPeak = 0
        downloadPeak = 0
    }
    
    func clearHistory() {
        speedHistory.removeAll()
    }
}

struct TrafficChartView: View {
    let stats: TrafficStats
    let maxPoints: Int
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let history = Array(stats.speedHistory.suffix(maxPoints))
                guard !history.isEmpty else { return }
                
                let maxWidth = size.width
                let maxHeight = size.height
                
                guard let maxSpeed = history.max(by: {
                    max($0.uploadSpeed, $0.downloadSpeed) < max($1.uploadSpeed, $1.downloadSpeed)
                }) else { return }
                
                let scale = max(maxSpeed.uploadSpeed, maxSpeed.downloadSpeed) > 0 ? maxHeight / max(maxSpeed.uploadSpeed, maxSpeed.downloadSpeed) : 1
                
                for i in 1..<history.count {
                    let x0 = Double(i - 1) / Double(max(maxPoints - 1, 1)) * maxWidth
                    let y0 = maxHeight - history[i - 1].uploadSpeed * scale
                    
                    let x1 = Double(i) / Double(max(maxPoints - 1, 1)) * maxWidth
                    let y1 = maxHeight - history[i].uploadSpeed * scale
                    
                    let path = Path { path in
                        path.move(to: CGPoint(x: x0, y: y0))
                        path.addLine(to: CGPoint(x: x1, y: y1))
                    }
                    
                    context.stroke(path, with: .color(Color.blue), style: StrokeStyle(lineWidth: 2))
                    
                    // Download
                    let y0Down = maxHeight - history[i - 1].downloadSpeed * scale
                    let y1Down = maxHeight - history[i].downloadSpeed * scale
                    
                    let downloadPath = Path { path in
                        path.move(to: CGPoint(x: x0, y: y0Down))
                        path.addLine(to: CGPoint(x: x1, y: y1Down))
                    }
                    
                    context.stroke(downloadPath, with: .color(Color.green), style: StrokeStyle(lineWidth: 2))
                }
            }
        }
        .frame(height: 100)
    }
}
