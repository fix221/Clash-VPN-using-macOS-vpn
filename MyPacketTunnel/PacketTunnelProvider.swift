import NetworkExtension
import os.log

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    private let logger = OSLog(subsystem: "com.myclash.MyPacketTunnel", category: "PacketTunnel")
    private var packetForwarder: PacketForwarder?
    private var mihomoManager: MihomoManager?
    private var configManager: ClashConfigManager?
    private var readPacketCount: UInt64 = 0
    private var writePacketCount: UInt64 = 0
    private var totalBytesRead: UInt64 = 0
    private var totalBytesWritten: UInt64 = 0
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        os_log("Starting tunnel...", log: logger, type: .info)
        
        // Initialize managers
        configManager = ClashConfigManager(logger: logger)
        mihomoManager = MihomoManager(logger: logger)
        
        // Configure the tunnel network settings
        let tunnelNetworkSettings = createTunnelNetworkSettings()
        
        setTunnelNetworkSettings(tunnelNetworkSettings) { error in
            if let error = error {
                os_log("Failed to set tunnel network settings: %{public}@", log: self.logger, type: .error, error.localizedDescription)
                completionHandler(error)
                return
            }
            
            os_log("Tunnel network settings configured successfully", log: self.logger, type: .info)
            
            // Start Mihomo core
            self.startMihomoCore { mihomoError in
                if let mihomoError = mihomoError {
                    os_log("Failed to start Mihomo: %{public}@", log: self.logger, type: .error, mihomoError.localizedDescription)
                    // Continue anyway for testing without Mihomo
                } else {
                    os_log("Mihomo started successfully", log: self.logger, type: .info)
                }
                
                // Initialize packet forwarder
                self.packetForwarder = PacketForwarder(packetFlow: self.packetFlow, logger: self.logger)
                
                // Start reading packets
                self.startReadingPackets()
                
                completionHandler(nil)
            }
        }
    }
    
    private func startMihomoCore(completion: @escaping (Error?) -> Void) {
        guard let configManager = configManager, let mihomoManager = mihomoManager else {
            completion(NSError(domain: "com.myclash.PacketTunnelProvider", code: 1,
                             userInfo: [NSLocalizedDescriptionKey: "Managers not initialized"]))
            return
        }
        
        // Check if we have a saved config, otherwise create a default one
        let configs = configManager.listConfigs()
        let configName = configs.first ?? "default"
        
        do {
            var configPath: String
            if configs.isEmpty {
                // Generate a default configuration
                let defaultConfig = configManager.generateMihomoConfig(proxyServers: [], rules: [])
                let yamlContent = configManager.configToYaml(defaultConfig)
                configPath = try configManager.saveConfig(name: "default", content: yamlContent)
            } else {
                configPath = "\(configManager.configDirectory)/\(configName).yaml"
            }
            
            // Start Mihomo
            mihomoManager.start(configPath: configPath) { error in
                completion(error)
            }
        } catch {
            os_log("Failed to prepare config: %{public}@", log: logger, type: .error, error.localizedDescription)
            completion(error)
        }
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        os_log("Stopping tunnel with reason: %{public}d", log: logger, type: .info, reason.rawValue)
        os_log("Final stats - Read packets: %llu, Write packets: %llu, Bytes read: %llu, Bytes written: %llu", 
               log: logger, type: .info, 
               readPacketCount, writePacketCount, totalBytesRead, totalBytesWritten)
        
        packetForwarder?.stop()
        packetForwarder = nil
        
        mihomoManager?.stop()
        mihomoManager = nil
        
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        os_log("Received app message", log: logger, type: .info)
        
        // Handle messages from the main app
        if let handler = completionHandler {
            // Parse message and respond
            if let message = String(data: messageData, encoding: .utf8) {
                os_log("Message content: %{public}@", log: logger, type: .debug, message)
                
                // Handle specific commands
                if message == "getStatus" {
                    let status: [String: Any] = [
                        "mihomoRunning": mihomoManager?.running ?? false,
                        "readPackets": readPacketCount,
                        "writePackets": writePacketCount,
                        "bytesRead": totalBytesRead,
                        "bytesWritten": totalBytesWritten
                    ]
                    if let responseData = try? JSONSerialization.data(withJSONObject: status) {
                        handler(responseData)
                        return
                    }
                }
            }
            
            handler(messageData)
        }
    }
    
    override func sleep(completionHandler: @escaping () -> Void) {
        os_log("Sleep requested", log: logger, type: .info)
        completionHandler()
    }
    
    override func wake() {
        os_log("Wake received", log: logger, type: .info)
    }
    
    private func createTunnelNetworkSettings() -> NEPacketTunnelNetworkSettings {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "10.0.0.1")
        
        // Configure IPv4 settings
        let ipv4Settings = NEIPv4Settings(addresses: ["10.0.0.2"], subnetMasks: ["255.255.255.0"])
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4Settings
        
        // Configure IPv6 settings (optional)
        let ipv6Settings = NEIPv6Settings(addresses: ["fd00::2"], networkPrefixLengths: [64])
        ipv6Settings.includedRoutes = [NEIPv6Route.default()]
        settings.ipv6Settings = ipv6Settings
        
        // Configure DNS - use local DNS server that Mihomo will intercept
        settings.dnsSettings = NEDNSSettings(servers: ["198.18.0.1"])
        
        // Configure MTU
        settings.mtu = NSNumber(value: 1500)
        
        return settings
    }
    
    private func startReadingPackets() {
        os_log("Starting packet reading", log: logger, type: .info)
        
        guard let forwarder = packetForwarder else {
            os_log("No packet forwarder initialized", log: logger, type: .error)
            return
        }
        
        // Start the packet forwarder
        forwarder.start { [weak self] packets, protocols in
            guard let self = self else { return }
            
            for packet in packets {
                
                // Update counters
                self.readPacketCount += 1
                self.totalBytesRead += UInt64(packet.count)
                
                // Log packet information periodically (every 100 packets)
                if self.readPacketCount % 100 == 0 {
                    os_log("Packet stats - Read: %llu packets (%llu bytes), Write: %llu packets (%llu bytes)", 
                           log: self.logger, type: .info,
                           self.readPacketCount, self.totalBytesRead,
                           self.writePacketCount, self.totalBytesWritten)
                }
            }
        }
    }
}
