import Foundation
import os.log

/// ClashConfigManager handles Clash-compatible configuration files
class ClashConfigManager {
    
    private let logger: OSLog
    let configDirectory: String
    
    init(logger: OSLog) {
        self.logger = logger
        // Use user's home directory for config storage
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        self.configDirectory = "\(homeDir)/Library/Application Support/MyClash/profiles"
        
        // Create config directory if it doesn't exist
        try? FileManager.default.createDirectory(atPath: configDirectory, withIntermediateDirectories: true)
    }
    
    /// Save a Clash configuration
    func saveConfig(name: String, content: String) throws -> String {
        let filePath = "\(configDirectory)/\(name).yaml"
        try content.write(toFile: filePath, atomically: true, encoding: .utf8)
        os_log("Saved config to %{public}@", log: logger, type: .info, filePath)
        return filePath
    }
    
    /// Load a Clash configuration
    func loadConfig(name: String) throws -> String {
        let filePath = "\(configDirectory)/\(name).yaml"
        return try String(contentsOfFile: filePath, encoding: .utf8)
    }
    
    /// List available configurations
    func listConfigs() -> [String] {
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: configDirectory)
            return files.filter { $0.hasSuffix(".yaml") || $0.hasSuffix(".yml") }
                        .map { ($0 as NSString).deletingPathExtension }
        } catch {
            os_log("Failed to list configs: %{public}@", log: logger, type: .error, error.localizedDescription)
            return []
        }
    }
    
    /// Generate a basic Mihomo TUN configuration
    func generateMihomoConfig(proxyServers: [[String: Any]], rules: [[String: Any]]) -> [String: Any] {
        var config: [String: Any] = [:]
        
        // Mixed port for HTTP/SOCKS
        config["mixed-port"] = 7890
        
        // Allow LAN connections
        config["allow-lan"] = false
        
        // Bind address
        config["bind-address"] = "*"
        
        // Mode
        config["mode"] = "rule"
        
        // Log level
        config["log-level"] = "info"
        
        // External controller (API)
        config["external-controller"] = "127.0.0.1:9090"
        
        // TUN configuration
        config["tun"] = [
            "enable": true,
            "stack": "gvisor",
            "auto-route": false,  // We handle routing ourselves
            "auto-detect-interface": true,
            "dns-hijack": ["any:53"],
            "device": "utun_mihomo"
        ] as [String : Any]
        
        // DNS configuration
        config["dns"] = [
            "enable": true,
            "listen": "0.0.0.0:1053",
            "enhanced-mode": "fake-ip",
            "fake-ip-range": "198.18.0.1/16",
            "nameserver": ["8.8.8.8", "1.1.1.1"],
            "fallback": ["https://dns.google/dns-query"]
        ] as [String : Any]
        
        // Proxies
        config["proxies"] = proxyServers
        
        // Proxy groups
        config["proxy-groups"] = [
            [
                "name": "PROXY",
                "type": "select",
                "proxies": ["DIRECT"] + proxyServers.compactMap { $0["name"] as? String }
            ] as [String : Any]
        ]
        
        // Rules
        config["rules"] = rules.isEmpty ? [
            "DOMAIN-SUFFIX,google.com,PROXY",
            "DOMAIN-KEYWORD,google,PROXY",
            "GEOIP,CN,DIRECT",
            "MATCH,PROXY"
        ] : rules.compactMap { rule in
            if let type = rule["type"] as? String,
               let value = rule["value"] as? String,
               let policy = rule["policy"] as? String {
                return "\(type),\(value),\(policy)"
            }
            return nil
        }
        
        return config
    }
    
    /// Convert config dictionary to YAML string
    func configToYaml(_ config: [String: Any]) -> String {
        // Simple YAML serialization (in production, use a proper YAML library)
        var yaml = ""
        
        for (key, value) in config {
            if let dict = value as? [String: Any] {
                yaml += "\(key):\n"
                yaml += serializeDictionary(dict, indent: 2)
            } else if let array = value as? [Any] {
                yaml += "\(key):\n"
                yaml += serializeArray(array, indent: 2)
            } else {
                yaml += "\(key): \(value)\n"
            }
        }
        
        return yaml
    }
    
    private func serializeDictionary(_ dict: [String: Any], indent: Int) -> String {
        var result = ""
        let padding = String(repeating: " ", count: indent)
        
        for (key, value) in dict {
            if let subDict = value as? [String: Any] {
                result += "\(padding)\(key):\n"
                result += serializeDictionary(subDict, indent: indent + 2)
            } else if let array = value as? [Any] {
                result += "\(padding)\(key):\n"
                result += serializeArray(array, indent: indent + 2)
            } else {
                result += "\(padding)\(key): \(value)\n"
            }
        }
        
        return result
    }
    
    private func serializeArray(_ array: [Any], indent: Int) -> String {
        var result = ""
        let padding = String(repeating: " ", count: indent)
        
        for item in array {
            if let dict = item as? [String: Any] {
                result += "\(padding)- "
                var first = true
                for (key, value) in dict {
                    if first {
                        result += "\(key): \(value)\n"
                        first = false
                    } else {
                        result += "\(padding)  \(key): \(value)\n"
                    }
                }
            } else {
                result += "\(padding)- \(item)\n"
            }
        }
        
        return result
    }
}
