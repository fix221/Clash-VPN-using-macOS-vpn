import Foundation
import SwiftUI

enum RoutingMode: String, CaseIterable, Identifiable {
    case rule = "Rule"
    case global = "Global"
    case direct = "Direct"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .rule: return "Traffic is decided by Clash rules"
        case .global: return "All traffic goes through the proxy"
        case .direct: return "All traffic bypasses the proxy"
        }
    }
}

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published var routingMode: RoutingMode = .rule
    @Published var dnsMode: DNSMode = .automatic
    @Published var customDNSServer: String = "223.5.5.5"
    @Published var ipv6Enabled: Bool = false
    @Published var mtu: Int = 1500
    @Published var logLevel: LogLevel = .info
    @Published var enableTrafficStats: Bool = true
    @Published var enableAppNameInTray: Bool = true
    @Published var allowLAN: Bool = false
    
    private let routingModeKey = "myclash_routing_mode"
    private let dnsModeKey = "myclash_dns_mode"
    private let customDNSServerKey = "myclash_dns_server"
    private let ipv6EnabledKey = "myclash_ipv6_enabled"
    private let mtuKey = "myclash_mtu"
    private let logLevelKey = "myclash_log_level"
    private let trafficStatsKey = "myclash_traffic_stats"
    private let trayNameKey = "myclash_tray_name"
    private let allowLANKey = "myclash_allow_lan"
    
    private init() {
        loadSettings()
    }
    
    func loadSettings() {
        if let modeRaw = UserDefaults.standard.string(forKey: routingModeKey),
           let mode = RoutingMode(rawValue: modeRaw) {
            routingMode = mode
        }
        
        if let dnsRaw = UserDefaults.standard.string(forKey: dnsModeKey),
           let mode = DNSMode(rawValue: dnsRaw) {
            dnsMode = mode
        }
        
        if let server = UserDefaults.standard.string(forKey: customDNSServerKey) {
            customDNSServer = server
        }
        
        ipv6Enabled = UserDefaults.standard.bool(forKey: ipv6EnabledKey)
        
        if let mtuValue = UserDefaults.standard.object(forKey: mtuKey) as? Int {
            mtu = mtuValue
        }
        
        if let logRaw = UserDefaults.standard.string(forKey: logLevelKey),
           let level = LogLevel(rawValue: logRaw) {
            logLevel = level
        }
        
        enableTrafficStats = UserDefaults.standard.bool(forKey: trafficStatsKey)
        enableAppNameInTray = UserDefaults.standard.bool(forKey: trayNameKey)
        allowLAN = UserDefaults.standard.bool(forKey: allowLANKey)
    }
    
    func saveSettings() {
        UserDefaults.standard.set(routingMode.rawValue, forKey: routingModeKey)
        UserDefaults.standard.set(dnsMode.rawValue, forKey: dnsModeKey)
        UserDefaults.standard.set(customDNSServer, forKey: customDNSServerKey)
        UserDefaults.standard.set(ipv6Enabled, forKey: ipv6EnabledKey)
        UserDefaults.standard.set(mtu, forKey: mtuKey)
        UserDefaults.standard.set(logLevel.rawValue, forKey: logLevelKey)
        UserDefaults.standard.set(enableTrafficStats, forKey: trafficStatsKey)
        UserDefaults.standard.set(enableAppNameInTray, forKey: trayNameKey)
        UserDefaults.standard.set(allowLAN, forKey: allowLANKey)
    }
    
    func resetToDefaults() {
        routingMode = .rule
        dnsMode = .automatic
        customDNSServer = "223.5.5.5"
        ipv6Enabled = false
        mtu = 1500
        logLevel = .info
        enableTrafficStats = true
        enableAppNameInTray = true
        allowLAN = false
        saveSettings()
    }
    
    func exportSettings() -> String {
        let dict: [String: Any] = [
            "routingMode": routingMode.rawValue,
            "dnsMode": dnsMode.rawValue,
            "customDNSServer": customDNSServer,
            "ipv6Enabled": ipv6Enabled,
            "mtu": mtu,
            "logLevel": logLevel.rawValue,
            "enableTrafficStats": enableTrafficStats,
            "enableAppNameInTray": enableAppNameInTray,
            "allowLAN": allowLAN
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "{}"
    }
    
    func importSettings(jsonString: String) throws {
        guard let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "SettingsManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON"])
        }
        
        if let mode = dict["routingMode"] as? String, let modeEnum = RoutingMode(rawValue: mode) {
            routingMode = modeEnum
        }
        
        if let mode = dict["dnsMode"] as? String, let modeEnum = DNSMode(rawValue: mode) {
            dnsMode = modeEnum
        }
        
        if let server = dict["customDNSServer"] as? String {
            customDNSServer = server
        }
        
        if let enabled = dict["ipv6Enabled"] as? Bool {
            ipv6Enabled = enabled
        }
        
        if let mtuValue = dict["mtu"] as? Int {
            mtu = mtuValue
        }
        
        if let level = dict["logLevel"] as? String, let levelEnum = LogLevel(rawValue: level) {
            logLevel = levelEnum
        }
        
        if let enabled = dict["enableTrafficStats"] as? Bool {
            enableTrafficStats = enabled
        }
        
        if let enabled = dict["enableAppNameInTray"] as? Bool {
            enableAppNameInTray = enabled
        }
        
        if let enabled = dict["allowLAN"] as? Bool {
            allowLAN = enabled
        }
        
        saveSettings()
    }
}

enum DNSMode: String, CaseIterable, Identifiable {
    case automatic = "Automatic"
    case custom = "Custom"
    case sistema = "System"
    
    var id: String { rawValue }
}
