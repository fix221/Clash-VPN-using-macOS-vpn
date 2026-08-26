import Foundation
import NetworkExtension
import Combine

class VPNManager: ObservableObject {
    static let shared = VPNManager()
    
    @Published var vpnStatus: NEVPNStatus = .disconnected
    @Published var isConnected: Bool = false
    @Published var errorMessage: String?
    @Published var manager: NETunnelProviderManager?
    
    private var timer: Timer?
    
    private init() {
        loadManager()
    }
    
    func loadManager() {
        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            if let error = error {
                print("Failed to load VPN managers: \(error.localizedDescription)")
                return
            }
            
            if let manager = managers?.first {
                DispatchQueue.main.async {
                    self.manager = manager
                    self.vpnStatus = manager.connection.status
                    self.isConnected = (manager.connection.status == .connected)
                    self.startMonitoring()
                }
            } else {
                createNewVPNConfiguration()
            }
        }
    }
    
    private func createNewVPNConfiguration() {
        let manager = NETunnelProviderManager()
        manager.localizedDescription = "MyClash VPN"
        
        let protocolConfig = NETunnelProviderProtocol()
        protocolConfig.providerBundleIdentifier = "com.myclash.MyPacketTunnel"
        protocolConfig.serverAddress = "MyClash VPN"
        manager.protocolConfiguration = protocolConfig
        
        manager.isEnabled = true
        manager.saveToPreferences { error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to save VPN configuration: \(error.localizedDescription)"
                }
                return
            }
            
            manager.loadFromPreferences { error in
                if let error = error {
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to load VPN configuration: \(error.localizedDescription)"
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    self.manager = manager
                    self.startMonitoring()
                }
            }
        }
    }
    
    private func startMonitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            guard let manager = self.manager else { return }
            
            let newStatus = manager.connection.status
            if newStatus != self.vpnStatus {
                self.vpnStatus = newStatus
                self.isConnected = (newStatus == .connected)
            }
        }
    }
    
    func connect() {
        guard let manager = manager else {
            errorMessage = "VPN configuration not found"
            return
        }
        
        manager.isEnabled = true
        manager.saveToPreferences { [weak self] error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.errorMessage = "Failed to save VPN configuration: \(error.localizedDescription)"
                }
                return
            }
            
            manager.loadFromPreferences { [weak self] error in
                if let error = error {
                    DispatchQueue.main.async {
                        self?.errorMessage = "Failed to load VPN configuration: \(error.localizedDescription)"
                    }
                    return
                }
                
                do {
                    try manager.connection.startVPNTunnel()
                    self?.vpnStatus = .connecting
                } catch {
                    DispatchQueue.main.async {
                        self?.errorMessage = "Failed to start VPN: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    func disconnect() {
        guard let manager = manager else { return }
        manager.connection.stopVPNTunnel()
        vpnStatus = .disconnecting
    }
    
    func toggle() {
        if isConnected {
            disconnect()
        } else {
            connect()
        }
    }
    
    func sendAppMessage(_ message: String, completion: ((Data?) -> Void)? = nil) {
        guard let manager = manager else { return }
        guard let data = message.data(using: .utf8) else { return }
        
        manager.connection.sendProviderMessage(data) { responseData in
            DispatchQueue.main.async {
                completion?(responseData)
            }
        }
    }
    
    func getStatus() {
        guard let manager = manager else { return }
        vpnStatus = manager.connection.status
        isConnected = (vpnStatus == .connected)
    }
    
    func getStatusText() -> String {
        switch vpnStatus {
        case .connected: return "Connected"
        case .connecting: return "Connecting..."
        case .disconnecting: return "Disconnecting..."
        case .disconnected: return "Disconnected"
        case .invalid: return "Invalid"
        case .reasserting: return "Reasserting..."
        @unknown default: return "Unknown"
        }
    }
}
