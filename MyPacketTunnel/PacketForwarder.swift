import NetworkExtension
import os.log

/// PacketForwarder handles reading packets from the tunnel and forwarding them
/// This is a placeholder implementation that will be replaced by Mihomo integration in Phase 6
class PacketForwarder {
    
    private let packetFlow: NEPacketTunnelFlow
    private let logger: OSLog
    private var isRunning = false
    private var onPacketsRead: (([Data], [NSNumber]) -> Void)?
    
    init(packetFlow: NEPacketTunnelFlow, logger: OSLog) {
        self.packetFlow = packetFlow
        self.logger = logger
    }
    
    /// Start reading packets from the tunnel
    func start(onPacketsRead: @escaping ([Data], [NSNumber]) -> Void) {
        guard !isRunning else {
            os_log("Packet forwarder already running", log: logger, type: .default)
            return
        }
        
        self.onPacketsRead = onPacketsRead
        isRunning = true
        
        os_log("Packet forwarder started", log: logger, type: .info)
        
        // Begin reading packets
        readPackets()
    }
    
    /// Stop the packet forwarder
    func stop() {
        isRunning = false
        onPacketsRead = nil
        os_log("Packet forwarder stopped", log: logger, type: .info)
    }
    
    /// Write packets back to the tunnel (for testing/loopback)
    func writePackets(_ packets: [Data], withProtocols protocols: [NSNumber]) {
        packetFlow.writePackets(packets, withProtocols: protocols)
    }
    
    private func readPackets() {
        guard isRunning else { return }
        
        packetFlow.readPackets { [weak self] packets, protocols in
            guard let self = self, self.isRunning else { return }
            
            // Notify the callback about received packets
            self.onPacketsRead?(packets, protocols)
            
            // For Phase 5: Implement basic loopback forwarding for testing
            // In Phase 6, this will be replaced by Mihomo core processing
            self.forwardPackets(packets, protocols: protocols)
            
            // Continue reading
            self.readPackets()
        }
    }
    
    /// Forward packets - currently implements loopback for testing
    /// Will be replaced by Mihomo integration in Phase 6
    private func forwardPackets(_ packets: [Data], protocols: [NSNumber]) {
        // Phase 5: Basic loopback forwarding to verify tunnel works
        // This allows us to test that packets are flowing through the tunnel
        
        for (index, packet) in packets.enumerated() {
            let protocolNumber = protocols[index]
            
            // Log basic packet info for debugging
            if packet.count > 0 {
                let firstByte = packet[0]
                let ipVersion = (firstByte >> 4) & 0x0F
                
                os_log("Forwarding packet: version=%d, size=%d, protocol=%d", 
                       log: logger, type: .debug,
                       ipVersion, packet.count, protocolNumber.intValue)
            }
        }
        
        // Write packets back (loopback for testing)
        // In production, these would be sent through Mihomo proxy
        packetFlow.writePackets(packets, withProtocols: protocols)
    }
}
