import SwiftUI
import NetworkExtension

struct ContentView: View {
    @StateObject private var vpnManager = VPNManager.shared
    @StateObject private var profileManager = ProfileManager.shared
    @StateObject private var loggerManager = LoggerManager.shared
    @StateObject private var trafficStats = TrafficStats.shared
    @StateObject private var settingsManager = SettingsManager.shared
    
    var body: some View {
        TabView {
            DashboardViewFixed()
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }
            
            ProfilesView()
                .tabItem {
                    Label("Profiles", systemImage: "doc.text.fill")
                }
            
            LogsView()
                .tabItem {
                    Label("Logs", systemImage: "scroll.fill")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear.fill")
                }
        }
        .onAppear {
            loggerManager.log("Application launched", level: .info, category: "System")
        }
    }
}

// MARK: - Dashboard View
struct DashboardView: View {
    @ObservedObject private var vpnManager = VPNManager.shared
    @ObservedObject private var profileManager = ProfileManager.shared
    @ObservedObject private var trafficStats = TrafficStats.shared
    @StateObject private var settingsManager = SettingsManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("MyClash")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
            }
            
            StatusIndicator(status: vpnManager.vpnStatus)
            
            Button(action: { vpnManager.toggle() }) {
                HStack {
                    Image(systemName: vpnManager.isConnected ? "stop.fill" : "play.fill")
                    Text(vpnManager.isConnected ? "Disconnect VPN" : "Connect VPN")
                }
                .frame(minWidth: 200)
                .padding()
                .background(vpnManager.isConnected ? Color.red : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(vpnManager.vpnStatus == .connecting || vpnManager.vpnStatus == .disconnecting)
            
            if let error = vpnManager.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Traffic Statistics
            if vpnManager.isConnected {
                VStack(spacing: 10) {
                    Text("Traffic Statistics")
                        .font(.headline)
                    
                    HStack(spacing: 40) {
                        VStack {
                            HStack {
                                Image(systemName: "arrow.up.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Upload")
                            }
                            Text(trafficStats.formatSpeed(trafficStats.uploadSpeed))
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text(trafficStats.formatBytes(trafficStats.totalUpload))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack {
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundColor(.green)
                                Text("Download")
                            }
                            Text(trafficStats.formatSpeed(trafficStats.downloadSpeed))
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text(trafficStats.formatBytes(trafficStats.totalDownload))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    
                    // Peak speeds
                    HStack {
                        Text("Peak Upload: \(trafficStats.formatSpeed(trafficStats.uploadPeak))")
                        Spacer()
                        Text("Peak Download: \(trafficStats.formatSpeed(trafficStats.downloadPeak))")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(.top)
            }
            
            Spacer()
            
            // Configuration Info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Mode")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(settingsManager.routingMode.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("DNS")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(settingsManager.dnsMode.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Profile")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(profileManager.activeProfile?.name ?? "None")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            trafficStats.startTracking()
        }
        .onDisappear {
            trafficStats.stopTracking()
        }
    }
}

// MARK: - Profiles View
struct ProfilesView: View {
    @StateObject private var profileManager = ProfileManager.shared
    @State private var showImportURL = false
    @State private var showAddProfile = false
    @State private var showEditor = false
    @State private var editingProfile: Profile?
    @State private var urlText = ""
    @State private var importError: String?
    
    var body: some View {
        HSplitView {
            // Profile List
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Profiles")
                        .font(.headline)
                    Spacer()
                    
                    Button(action: { showImportURL = true }) {
                        Image(systemName: "link.badge.plus")
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: { showAddProfile = true }) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.bordered)
                }
                
                Divider()
                
                List(profileManager.profiles) { profile in
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(profile.isDefault ? .blue : .gray)
                        VStack(alignment: .leading) {
                            Text(profile.name)
                                .font(.body)
                            if let url = profile.url {
                                Text(url)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        if profile.isDefault {
                            Text("Active")
                                .font(.caption2)
                                .padding(4)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                    }
                    .contentShape(Rectangle())
                    .contextMenu {
                        Button("Set as Active") {
                            profileManager.setActiveProfile(profile)
                        }
                        
                        Button("Edit") {
                            editingProfile = profile
                            showEditor = true
                        }
                        
                        Divider()
                        
                        Button("Delete", role: .destructive) {
                            profileManager.deleteProfile(profile)
                        }
                    }
                }
                .listStyle(.bordered(alternatesRowBackgrounds: true))
            }
            .frame(minWidth: 300)
            
            // Profile Detail
            if let profile = profileManager.activeProfile {
                ScrollView {
                    Text(profile.content)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                }
                .frame(minWidth: 400, minHeight: 300)
            } else {
                VStack {
                    Spacer()
                    Text("No active profile")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(minWidth: 400)
            }
        }
        .frame(minWidth: 700, minHeight: 400)
        .sheet(isPresented: $showImportURL) {
            ImportURLView(urlText: $urlText, importError: $importError) { url in
                profileManager.importProfileFromURL(url: url)
            }
        }
        .sheet(isPresented: $showEditor) {
            ProfileEditorView(profile: $editingProfile)
        }
    }
}

// MARK: - Logs View  
struct LogsView: View {
    @StateObject private var loggerManager = LoggerManager.shared
    @State private var searchQuery = ""
    @State private var filterLevel: LogLevel?
    
    var filteredLogs: [LogEntry] {
        var logs = loggerManager.logs
        
        if !searchQuery.isEmpty {
            logs = logs.filter { $0.message.lowercased().contains(searchQuery.lowercased()) }
        }
        
        if let level = filterLevel {
            logs = logs.filter { $0.level == level }
        }
        
        return logs
    }
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Logs")
                    .font(.headline)
                
                Spacer()
                
                Picker("Filter", selection: $filterLevel) {
                    Text("All").tag(LogLevel?.none)
                    Text("Error").tag(LogLevel.error)
                    Text("Warning").tag(LogLevel.warning)
                    Text("Info").tag(LogLevel.info)
                    Text("Debug").tag(LogLevel.debug)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
                
                Button(action: { loggerManager.clearLogs() }) {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                
                Button(action: {
                    let logs = loggerManager.exportLogs()
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(logs, forType: .string)
                }) {
                    Label("Export", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
            }
            
            Divider()
            
            TextField("Search logs...", text: $searchQuery)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 300)
            
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(filteredLogs.reversed()) { log in
                        HStack(spacing: 10) {
                            Text(log.formattedTimestamp)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                            
                            Text(log.level.rawValue)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(log.level.color.opacity(0.2))
                                .foregroundColor(log.level.color)
                                .cornerRadius(4)
                            
                            Text("[\(log.category)]")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Text(log.message)
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(3)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(log.message, forType: .string)
                        }
                    }
                }
            }
        }
        .padding()
        .frame(minWidth: 700, minHeight: 400)
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @StateObject private var settingsManager = SettingsManager.shared
    
    var body: some View {
        ScrollView {
            Form {
                Section("VPN Settings") {
                    Picker("Routing Mode", selection: $settingsManager.routingMode) {
                        ForEach(RoutingMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .onChange(of: settingsManager.routingMode) { _ in
                        settingsManager.saveSettings()
                    }
                    
                    Text(settingsManager.routingMode.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("DNS Mode", selection: $settingsManager.dnsMode) {
                        ForEach(DNSMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .onChange(of: settingsManager.dnsMode) { _ in
                        settingsManager.saveSettings()
                    }
                    
                    if settingsManager.dnsMode == .custom {
                        TextField("Custom DNS Server", text: $settingsManager.customDNSServer)
                            .onChange(of: settingsManager.customDNSServer) { _ in
                                settingsManager.saveSettings()
                            }
                    }
                    
                    Toggle("Enable IPv6", isOn: $settingsManager.ipv6Enabled)
                        .onChange(of: settingsManager.ipv6Enabled) { _ in
                            settingsManager.saveSettings()
                        }
                    
                    HStack {
                        Text("MTU")
                        Spacer()
                        TextField("MTU", value: $settingsManager.mtu, formatter: NumberFormatter())
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .onChange(of: settingsManager.mtu) { _ in
                                settingsManager.saveSettings()
                            }
                    }
                }
                
                Section("Appearance") {
                    Toggle("Enable Traffic Statistics", isOn: $settingsManager.enableTrafficStats)
                        .onChange(of: settingsManager.enableTrafficStats) { _ in
                            settingsManager.saveSettings()
                        }
                }
                
                Section("Advanced") {
                    Toggle("Allow LAN", isOn: $settingsManager.allowLAN)
                        .onChange(of: settingsManager.allowLAN) { _ in
                            settingsManager.saveSettings()
                        }
                    
                    LabeledContent("Application Directory") {
                        Text(NSHomeDirectory())
                    }
                }
                
                Section("Data") {
                    Button("Reset to Defaults") {
                        settingsManager.resetToDefaults()
                    }
                    .buttonStyle(.bordered)
                    
                    HStack {
                        Button("Export Settings") {
                            let json = settingsManager.exportSettings()
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(json, forType: .string)
                        }
                        
                        Button("Import Settings") {
                            let pasteboard = NSPasteboard.general
                            if let json = pasteboard.string(forType: .string) {
                                (try? settingsManager.importSettings(jsonString: json))
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .frame(width: 500)
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

// MARK: - Import URL View
struct ImportURLView: View {
    @Binding var urlText: String
    @Binding var importError: String?
    var onImport: (String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Import Profile from URL")
                .font(.headline)
            
            TextField("https://example.com/profile.yaml", text: $urlText)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    importProfile()
                }
            
            if let error = importError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button("Import") {
                    importProfile()
                }
                .buttonStyle(.borderedProminent)
                .disabled(urlText.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }
    
    private func importProfile() {
        guard !urlText.trimmingCharacters(in: .whitespaces).isEmpty else {
            importError = "URL cannot be empty"
            return
        }
        
        onImport(urlText)
        dismiss()
    }
}

// MARK: - Profile Editor View
struct ProfileEditorView: View {
    @Binding var profile: Profile?
    @State private var content: String
    
    @Environment(\.dismiss) private var dismiss
    
    init(profile: Binding<Profile?>) {
        self._profile = profile
        self._content = State(initialValue: profile.wrappedValue?.content ?? "")
    }
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Edit Profile")
                    .font(.headline)
                Spacer()
                Button("Close") { dismiss() }
            }
            
            Divider()
            
            TextEditor(text: $content)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 300)
            
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                Spacer()
                Button("Save") {
                    if let profile = profile {
                        ProfileManager.shared.updateProfile(profile, content: content)
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(minWidth: 600, minHeight: 450)
    }
}

// MARK: - Status Indicator
struct StatusIndicator: View {
    let status: NEVPNStatus
    
    var statusText: String {
        switch status {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting..."
        case .disconnecting:
            return "Disconnecting..."
        case .disconnected:
            return "Disconnected"
        case .invalid:
            return "Invalid"
        case .reasserting:
            return "Reasserting..."
        @unknown default:
            return "Unknown"
        }
    }
    
    var statusColor: Color {
        switch status {
        case .connected:
            return .green
        case .connecting, .reasserting:
            return .yellow
        case .disconnecting:
            return .orange
        case .disconnected, .invalid:
            return .red
        @unknown default:
            return .gray
        }
    }
    
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor)
                .frame(width: 16, height: 16)
                .overlay(
                    Circle()
                        .stroke(statusColor, lineWidth: 2)
                        .frame(width: 20, height: 20)
                        .opacity(status == .connecting || status == .reasserting ? 0.5 : 0)
                )
            Text(statusText)
                .font(.title2)
                .fontWeight(.semibold)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// Fix: DashboardView needs @StateObject for settingsManager
struct DashboardViewFixed: View {
    @ObservedObject private var vpnManager = VPNManager.shared
    @ObservedObject private var profileManager = ProfileManager.shared
    @ObservedObject private var trafficStats = TrafficStats.shared
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var loggerManager = LoggerManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("MyClash")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                Text("v1.0.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            StatusIndicator(status: vpnManager.vpnStatus)
            
            Button(action: { vpnManager.toggle() }) {
                HStack {
                    Image(systemName: vpnManager.isConnected ? "stop.fill" : "play.fill")
                    Text(vpnManager.isConnected ? "Disconnect VPN" : "Connect VPN")
                        .font(.headline)
                }
                .frame(minWidth: 220)
                .padding()
                .background(vpnManager.isConnected ? Color.red : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(vpnManager.vpnStatus == .connecting || vpnManager.vpnStatus == .disconnecting)
            
            if let error = vpnManager.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Traffic Statistics
            if vpnManager.isConnected {
                VStack(spacing: 12) {
                    Text("Traffic Statistics")
                        .font(.headline)
                    
                    HStack(spacing: 50) {
                        VStack {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Upload")
                            }
                            Text(trafficStats.formatSpeed(trafficStats.uploadSpeed))
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                            Text(trafficStats.formatBytes(trafficStats.totalUpload))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundColor(.green)
                                Text("Download")
                            }
                            Text(trafficStats.formatSpeed(trafficStats.downloadSpeed))
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                            Text(trafficStats.formatBytes(trafficStats.totalDownload))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    HStack {
                        Text("Peak ↑: \(trafficStats.formatSpeed(trafficStats.uploadPeak))")
                        Spacer()
                        Text("Peak ↓: \(trafficStats.formatSpeed(trafficStats.downloadPeak))")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Mode", systemImage: "route.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(settingsManager.routingMode.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
                
                HStack {
                    Label("DNS", systemImage: "globe")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(settingsManager.dnsMode.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Label("Profile", systemImage: "doc.text.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(profileManager.activeProfile?.name ?? "None")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(10)
        }
        .padding()
        .frame(minWidth: 450, minHeight: 380)
        .onAppear {
            trafficStats.startTracking()
            loggerManager.log("Dashboard appeared", level: .debug, category: "UI")
        }
        .onDisappear {
            trafficStats.stopTracking()
        }
    }
}
