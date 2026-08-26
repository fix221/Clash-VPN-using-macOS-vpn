# MyClash - macOS Clash VPN Client

A native macOS VPN client that uses Apple's NetworkExtension framework with NEPacketTunnelProvider to provide system-wide VPN-style traffic interception, integrated with Mihomo (Clash-compatible core).

## Architecture

```
MyClash.app
├── Main macOS Application (SwiftUI)
│   ├── VPN start/stop control
│   ├── Status monitoring
│   └── Configuration management
│
└── MyPacketTunnel.appex
    └── NEPacketTunnelProvider
        ├── Packet flow handling
        ├── VPN network configuration
        └── Traffic routing
```

## Key Features

- **No Root Privileges Required**: Runs from user-writable directories (~/Downloads, ~/Applications)
- **No System Extension**: Uses only NEPacketTunnelProvider
- **No System Proxy Dependency**: Intercepts traffic at VPN interface level
- **Full-Tunnel Routing**: All traffic goes through the VPN tunnel
- **DNS Configuration**: Configurable DNS servers through VPN settings
- **IPv4 & IPv6 Support**: Dual-stack network configuration

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later
- Apple Developer Account (for NetworkExtension entitlements)

## Building

1. Open `MyClash.xcodeproj` in Xcode
2. Select your development team in Signing & Capabilities
3. Build and run the MyClash target

```bash
# Build from command line
xcodebuild -project MyClash.xcodeproj -scheme MyClash -configuration Debug build
```

## Project Structure

```
clash_using_vpn/
├── MyClash.xcodeproj/
│   └── project.pbxproj
├── MyClash/
│   ├── MyClashApp.swift          # App entry point
│   ├── ContentView.swift         # Main UI
│   ├── Info.plist                # App configuration
│   ├── MyClash.entitlements      # App entitlements
│   └── Assets.xcassets/          # App assets
├── MyPacketTunnel/
│   ├── PacketTunnelProvider.swift # VPN tunnel implementation
│   ├── Info.plist                # Extension configuration
│   └── MyPacketTunnel.entitlements # Extension entitlements
├── AGENTS.md                     # Development instructions
└── README.md                     # This file
```

## Development Phases

### Phase 1 - Basic App ✅
- SwiftUI application structure
- Runs from user-writable directory

### Phase 2 - Packet Tunnel Extension ✅
- NEPacketTunnelProvider implementation
- Extension activation

### Phase 3 - VPN Configuration ✅
- NEPacketTunnelNetworkSettings
- IPv4/IPv6 configuration
- DNS settings
- MTU configuration

### Phase 4 - Packet Flow ✅
- readPackets() / writePackets()
- Packet logging and monitoring

### Phase 5 - Basic Forwarding ✅
- PacketForwarder class implementation
- Packet reading loop with callbacks
- Packet counters (read/write counts, byte totals)
- Detailed logging via OSLog
- Loopback forwarding for testing
- IP version detection (IPv4/IPv6)
- Periodic statistics reporting

### Phase 6 - Mihomo Integration (Pending)
- Integrate Mihomo core
- Protocol support (Shadowsocks, VMess, VLESS, Trojan, etc.)

### Phase 7 - Clash Configuration (Pending)
- Support proxies, proxy-groups, rules
- DNS configuration
- TUN mode

### Phase 8 - Production UI (Pending)
- Profile management
- Logs viewer
- Settings
- Connection statistics

## Important Notes

### Entitlements

The Packet Tunnel Extension requires:
- `com.apple.developer.networking.networkextension` with `packet-tunnel-provider`
- Proper code signing with Developer ID or App Store distribution

### MDM Constraints

- Application designed for non-administrator users
- May be blocked by MDM policies
- Reports exact system errors if activation fails

### Testing

To test the VPN functionality:

1. Build and run the app
2. Click "Connect VPN"
3. Check system logs for tunnel activation
4. Verify VPN status in System Settings > Network

## Troubleshooting

### VPN Activation Fails

Check the error details in the app UI. Common issues:
- Missing entitlements
- Code signing issues
- MDM policy restrictions
- User authorization not granted

### Logs

View logs using Console.app:
- Filter by subsystem: `com.myclash.MyPacketTunnel`
- Category: `PacketTunnel`

## License

This project is for educational and defensive security purposes only.

## References

- [Apple NetworkExtension Documentation](https://developer.apple.com/documentation/networkextension)
- [NEPacketTunnelProvider](https://developer.apple.com/documentation/networkextension/nepackettunnelprovider)
- [Mihomo (Clash Meta)](https://github.com/MetaCubeX/mihomo)
