import Foundation
import os.log

/// MihomoManager manages the Mihomo core process and provides proxy functionality
class MihomoManager {
    
    private let logger: OSLog
    private var process: Process?
    private var isRunning = false
    private var apiPort: Int = 9090
    private var configPath: String?
    
    init(logger: OSLog) {
        self.logger = logger
    }
    
    /// Start Mihomo core with the given configuration
    func start(configPath: String, completion: @escaping (Error?) -> Void) {
        guard !isRunning else {
            os_log("Mihomo already running", log: logger, type: .default)
            completion(nil)
            return
        }
        
        self.configPath = configPath
        
        // Find the mihomo binary in the bundle
        guard let mihomoPath = Bundle.main.path(forResource: "mihomo", ofType: nil) ??
                               Bundle.main.path(forResource: "mihomo-darwin", ofType: nil) else {
            let error = NSError(domain: "com.myclash.MihomoManager", code: 1, 
                              userInfo: [NSLocalizedDescriptionKey: "Mihomo binary not found"])
            os_log("Mihomo binary not found in bundle", log: logger, type: .error)
            completion(error)
            return
        }
        
        os_log("Starting Mihomo from: %{public}@", log: logger, type: .info, mihomoPath)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: mihomoPath)
        process.arguments = ["-d", configPath]
        
        // Set up pipes for stdout/stderr
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            self.process = process
            self.isRunning = true
            
            os_log("Mihomo started successfully with PID %d", log: logger, type: .info, process.processIdentifier)
            
            // Read output asynchronously
            pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                guard let self = self else { return }
                let data = handle.availableData
                if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                    os_log("Mihomo output: %{public}@", log: self.logger, type: .debug, output)
                }
            }
            
            // Wait a bit for Mihomo to start
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                completion(nil)
            }
        } catch {
            os_log("Failed to start Mihomo: %{public}@", log: logger, type: .error, error.localizedDescription)
            completion(error)
        }
    }
    
    /// Stop Mihomo core
    func stop() {
        guard isRunning else { return }
        
        os_log("Stopping Mihomo", log: logger, type: .info)
        
        process?.terminate()
        process?.waitUntilExit()
        process = nil
        isRunning = false
        
        os_log("Mihomo stopped", log: logger, type: .info)
    }
    
    /// Check if Mihomo is running
    var running: Bool {
        return isRunning && (process?.isRunning ?? false)
    }
    
    /// Get Mihomo API endpoint
    var apiEndpoint: String {
        return "http://127.0.0.1:\(apiPort)"
    }
    
    /// Reload configuration
    func reloadConfig(configPath: String, completion: @escaping (Error?) -> Void) {
        guard isRunning else {
            let error = NSError(domain: "com.myclash.MihomoManager", code: 2,
                              userInfo: [NSLocalizedDescriptionKey: "Mihomo not running"])
            completion(error)
            return
        }
        
        // Use Mihomo's API to reload config
        let url = URL(string: "\(apiEndpoint)/configs")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["path": configPath]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let task = URLSession.shared.dataTask(with: request) { _, _, error in
            if let error = error {
                os_log("Failed to reload config: %{public}@", log: self.logger, type: .error, error.localizedDescription)
                completion(error)
            } else {
                os_log("Config reloaded successfully", log: self.logger, type: .info)
                completion(nil)
            }
        }
        task.resume()
    }
    
    /// Get proxy groups from Mihomo
    func getProxyGroups(completion: @escaping ([String: Any]?, Error?) -> Void) {
        guard isRunning else {
            let error = NSError(domain: "com.myclash.MihomoManager", code: 3,
                              userInfo: [NSLocalizedDescriptionKey: "Mihomo not running"])
            completion(nil, error)
            return
        }
        
        let url = URL(string: "\(apiEndpoint)/proxies")!
        let task = URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                os_log("Failed to get proxies: %{public}@", log: self.logger, type: .error, error.localizedDescription)
                completion(nil, error)
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                let error = NSError(domain: "com.myclash.MihomoManager", code: 4,
                                  userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                completion(nil, error)
                return
            }
            
            completion(json, nil)
        }
        task.resume()
    }
    
    deinit {
        if isRunning {
            stop()
        }
    }
}
