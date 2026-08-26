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
    private let providerBundleIdentifier = "com.myclash.MyClash.MyPacketTunnel"
    
    private init() {
        loadManager()
    }
    
    func loadManager() {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            if let error = error {
                self?.reportError("Failed to load VPN configurations", error: error)
                return
            }
            
            if let manager = managers?.first {
                DispatchQueue.main.async {
                    self?.manager = manager
                    self?.vpnStatus = manager.connection.status
                    self?.isConnected = (manager.connection.status == .connected)
                    self?.startMonitoring()
                }
            } else {
                self?.createNewVPNConfiguration()
            }
        }
    }
    
    private func createNewVPNConfiguration() {
        let manager = NETunnelProviderManager()
        manager.localizedDescription = "MyClash VPN"
        
        let protocolConfig = NETunnelProviderProtocol()
        protocolConfig.providerBundleIdentifier = providerBundleIdentifier
        protocolConfig.serverAddress = "MyClash VPN"
        manager.protocolConfiguration = protocolConfig
        
        manager.isEnabled = true
        manager.saveToPreferences { error in
            if let error = error {
                self.reportError("Failed to save VPN configuration", error: error)
                return
            }
            
            manager.loadFromPreferences { error in
                if let error = error {
                    self.reportError("Failed to load VPN configuration", error: error)
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
                self?.reportError("Failed to save VPN configuration", error: error)
                return
            }
            
            manager.loadFromPreferences { [weak self] error in
                if let error = error {
                    self?.reportError("Failed to load VPN configuration", error: error)
                    return
                }
                
                do {
                    try manager.connection.startVPNTunnel()
                    self?.vpnStatus = .connecting
                } catch {
                    self?.reportError("Failed to start VPN", error: error)
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
        // Note: sendProviderMessage is not available on macOS NEVPNConnection
        // This method would need to be implemented through a different mechanism
        print("Warning: sendAppMessage is not supported on macOS")
        completion?(nil)
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

    private func reportError(_ operation: String, error: Error) {
        let nsError = error as NSError
        let details = """
        \(operation)
        Domain: \(nsError.domain)
        Code: \(nsError.code)
        Description: \(nsError.localizedDescription)
        Reason: \(nsError.localizedFailureReason ?? "Not provided")
        Recovery: \(nsError.localizedRecoverySuggestion ?? "Not provided")
        Provider: \(providerBundleIdentifier)
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        """

        print(details)
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = details
        }
    }
}
