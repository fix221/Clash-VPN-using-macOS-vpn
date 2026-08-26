# macOS Clash VPN Client Development Instructions

## 1. Project Goal

Develop a native macOS VPN client that behaves like a Clash/Mihomo client, but uses Apple's `NetworkExtension` framework and a `NEPacketTunnelProvider` rather than a System Extension.

The primary target environment is:

- macOS
- User does NOT have administrator/root privileges
- Mac may be managed by MDM
- The application must be runnable from a user-writable directory such as:
  - `~/Downloads/`
  - `~/Applications/`
- Do NOT require copying the application to `/Applications`
- Do NOT use a System Extension
- Do NOT install privileged helper tools
- Do NOT require root launch daemons
- Do NOT modify `/etc`
- Do NOT depend on macOS system HTTP/SOCKS proxy settings

The final architecture should provide system-wide VPN-style traffic interception.

---

## 2. Required Architecture

Use:

```text
MyClash.app
├── Main macOS Application
│   ├── SwiftUI UI
│   ├── configuration
│   ├── VPN start/stop
│   └── status monitoring
│
└── MyPacketTunnel.appex
    └── NEPacketTunnelProvider
```

The packet tunnel must use:

```text
NetworkExtension
    ↓
NEPacketTunnelProvider
    ↓
NEPacketTunnelFlow
    ↓
Mihomo / Clash-compatible core
    ↓
Proxy nodes
```

Do NOT implement:

```text
System Extension
Privileged Helper
SMJobBless
LaunchDaemon
Root daemon
Kernel extension
```

---

## 3. Important MDM Constraint

The application must be designed specifically for an environment where the user may not have administrator privileges.

Do NOT assume:

```text
sudo
root
/Applications write access
system-wide installation permissions
```

The app should be capable of existing at:

```text
~/Downloads/MyClash.app
```

or:

```text
~/Applications/MyClash.app
```

Do not hard-code `/Applications`.

If macOS itself requires user authorization to activate the VPN configuration, use the standard Apple NetworkExtension authorization flow. Do not attempt to bypass macOS or MDM restrictions.

If MDM prevents NetworkExtension activation, report the exact system error instead of attempting privilege escalation or bypassing MDM.

---

## 4. NetworkExtension Implementation

Use:

```swift
import NetworkExtension
```

The VPN implementation should use:

```swift
NEPacketTunnelProvider
```

The extension point should be:

```text
com.apple.networkextension.packet-tunnel
```

The Packet Tunnel Provider should configure an `NEPacketTunnelNetworkSettings`.

Initial configuration should support:

- IPv4
- IPv6 where practical
- Full-tunnel routing
- DNS configuration
- MTU configuration
- Automatic start/stop
- Packet flow monitoring

Example conceptual configuration:

```text
IPv4 address:
    10.0.0.2

IPv4 subnet:
    255.255.255.0

Default route:
    0.0.0.0/0

DNS:
    configurable

MTU:
    configurable
```

Do not assume these exact values are mandatory. Choose safe values and document them.

---

## 5. Packet Handling

The Packet Tunnel Provider should use:

```swift
packetFlow.readPackets(...)
packetFlow.writePackets(...)
```

Do not implement fake proxy behavior by changing:

```text
HTTP_PROXY
HTTPS_PROXY
SOCKS
macOS system proxy
```

The goal is to intercept IP traffic at the VPN interface level.

The first milestone should prove that:

1. VPN can be activated.
2. A virtual tunnel interface is created.
3. IP packets arrive at `NEPacketTunnelFlow`.
4. DNS configuration works.
5. Full-tunnel routing works.
6. Traffic can eventually reach the Internet through the tunnel implementation.

---

## 6. Mihomo Integration

After the basic Packet Tunnel implementation works, integrate Mihomo or another Clash-compatible core.

Preferred conceptual architecture:

```text
NEPacketTunnelProvider
        ↓
packetFlow
        ↓
Mihomo integration layer
        ↓
Clash routing rules
        ↓
Proxy / DIRECT
```

The core should support standard Clash-compatible configuration.

Potential protocols include:

- Shadowsocks
- VMess
- VLESS
- Trojan
- Hysteria2
- SOCKS5
- HTTP
- other protocols supported by the selected Mihomo version

Do not assume every protocol is available until verified against the exact Mihomo version being integrated.

---

## 7. Avoiding System Proxy

The application must NOT depend on:

```text
System Settings
→ Network
→ Proxies
```

The intended behavior is:

```text
Application
    ↓
macOS networking stack
    ↓
Packet Tunnel
    ↓
Mihomo
    ↓
Proxy server
```

Applications that ignore HTTP/SOCKS proxy settings should still be intercepted if macOS allows the Packet Tunnel to receive their traffic.

---

## 8. DNS

DNS must be handled through the VPN configuration.

Do not rely exclusively on:

```text
/etc/resolv.conf
```

or manual modification of macOS DNS settings.

Support configurable DNS servers.

The implementation must avoid obvious DNS leaks when full-tunnel mode is enabled.

Support at minimum:

```text
IPv4 DNS
IPv6 DNS where applicable
```

---

## 9. Routing Modes

Implement these modes if practical:

### Global

All traffic goes through the VPN:

```text
0.0.0.0/0
::/0
```

### Rule

Traffic is decided by Mihomo rules:

```text
DIRECT
PROXY
REJECT
```

### Direct

Useful for debugging the Packet Tunnel itself.

---

## 10. Application UI

Use SwiftUI.

Minimal UI:

```text
┌─────────────────────────────┐
│ MyClash                     │
│                             │
│       ● Disconnected        │
│                             │
│      [ Connect VPN ]        │
│                             │
│ Mode: Rule                  │
│ DNS:  Auto                  │
│                             │
│ Current Profile             │
│ default.yaml                │
└─────────────────────────────┘
```

Required functionality:

- Connect
- Disconnect
- VPN status
- Profile selection
- Import configuration
- Basic logs
- Error display

Do not add unnecessary UI before the VPN functionality works.

---

## 11. Configuration Storage

Store user configuration under the user's home directory.

Do not require root access.

Possible location:

```text
~/Library/Application Support/MyClash/
```

or another appropriate per-user application directory.

Configuration should include:

```text
profiles/
cache/
logs/
```

Do not write configuration to:

```text
/etc/
```

without explicit user permission and a strong reason.

---

## 12. Logging

Provide detailed diagnostics.

Log:

- VPN activation
- VPN deactivation
- NetworkExtension errors
- tunnel configuration
- DNS configuration
- routing configuration
- packet-flow status
- Mihomo startup/shutdown
- Mihomo errors

Never log:

- passwords
- private keys
- authentication tokens
- complete sensitive URLs containing credentials

Make logs accessible from the UI.

---

## 13. Entitlements

Use only the entitlements genuinely required by the implementation.

Investigate and correctly configure:

```text
com.apple.developer.networking.networkextension
```

for the Packet Tunnel Provider.

Do not add unrelated privileged entitlements.

If development signing prevents NetworkExtension from working, clearly document the required Apple Developer configuration.

Do not fake or bypass entitlements.

---

## 14. System Extension Prohibition

This project must NOT use:

```text
OSSystemExtensionRequest
OSSystemExtensionManager
SystemExtensions.framework
```

Do not create:

```text
.systemextension
```

Do not use MClash's System Extension architecture.

The entire point of this project is to determine whether a normal macOS application + Packet Tunnel Provider can operate under a restricted/MDM user environment.

---

## 15. Installation Requirement

The application should build into:

```text
MyClash.app
```

The development/test workflow should allow:

```bash
open ./MyClash.app
```

from any user-writable directory.

Do not require:

```bash
sudo cp MyClash.app /Applications/
```

Do not implement installation scripts that automatically request root privileges.

If macOS refuses activation because of a system or MDM policy, surface that failure clearly.

---

## 16. Development Phases

Implement in this order.

### Phase 1 — Basic App

Create:

```text
MyClash.app
```

with SwiftUI.

Verify that it runs from:

```text
~/Downloads/
```

without administrator privileges.

### Phase 2 — Packet Tunnel Extension

Create:

```text
MyPacketTunnel.appex
```

using:

```swift
NEPacketTunnelProvider
```

Verify extension activation.

### Phase 3 — VPN Configuration

Implement:

```text
NEPacketTunnelNetworkSettings
```

with:

- IPv4
- default route
- DNS
- MTU

Verify the VPN interface.

### Phase 4 — Packet Flow

Verify:

```text
readPackets()
writePackets()
```

and provide packet counters/logging.

### Phase 5 — Basic Forwarding

Implement the minimum forwarding mechanism necessary to make traffic traverse the tunnel.

### Phase 6 — Mihomo

Integrate Mihomo.

### Phase 7 — Clash Configuration

Support:

```text
proxies
proxy-groups
rules
dns
tun
```

as appropriate for the chosen integration architecture.

### Phase 8 — Production UI

Add:

- profiles
- logs
- settings
- connection status
- traffic statistics

---

## 17. Critical Technical Question

Before writing large amounts of code, investigate this exact question:

> Can a macOS application containing a `NEPacketTunnelProvider` App Extension be launched from `~/Downloads` or another user-writable location and activate its Packet Tunnel without requiring `/Applications`, administrator privileges, System Extension installation, or privileged helper installation?

Test this with the smallest possible project first.

This is the highest-priority technical validation.

Do not spend significant time integrating Mihomo until this question has been experimentally confirmed.

---

## 18. Failure Handling

If activation fails, record the complete error:

```text
domain
code
localizedDescription
localizedFailureReason
localizedRecoverySuggestion
```

Also print the macOS version and extension bundle identifier.

For example:

```text
NetworkExtension activation failed

Domain: ...
Code: ...
Description: ...
Reason: ...
Recovery: ...
```

Do not silently fall back to system proxy mode.

---

## 19. Security

Do not attempt to bypass:

- MDM
- macOS security controls
- SIP
- TCC
- NetworkExtension entitlement checks
- code-signing requirements
- administrator restrictions

The goal is to find a legitimate user-level NetworkExtension architecture that macOS permits.

If the MDM policy explicitly blocks it, report the restriction.

---

## 20. Expected Final Architecture

The preferred final architecture is:

```text
                         macOS
                           │
          ┌────────────────┴────────────────┐
          │                                 │
   MyClash.app                       MyPacketTunnel.appex
          │                                 │
     SwiftUI UI                      NEPacketTunnelProvider
          │                                 │
          └──────────────┬──────────────────┘
                         │
                  NetworkExtension
                         │
                  Virtual VPN Interface
                         │
                    IP Packets
                         │
                    Mihomo Core
                         │
              ┌──────────┴──────────┐
              │                     │
            DIRECT                PROXY
                                    │
                          VLESS / SS / etc.
                                    │
                                Internet
```

The project is successful only if it can provide VPN-style system-wide traffic interception without:

1. `/Applications` installation
2. System Extension
3. privileged helper
4. root daemon
5. modifying system proxy settings

Start with the smallest possible Packet Tunnel Provider proof-of-concept and test the MDM/no-admin constraint before implementing Mihomo.