import Foundation
import SwiftUI

struct Profile: Identifiable, Codable {
    let id: String
    var name: String
    var url: String?
    var content: String
    var isDefault: Bool
    var createdAt: Date
    var updatedAt: Date
    var lastUsed: Date?
    
    init(id: String = UUID().uuidString, name: String, url: String? = nil, content: String = "", isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.url = url
        self.content = content
        self.isDefault = isDefault
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

class ProfileManager: ObservableObject {
    static let shared = ProfileManager()
    
    @Published var profiles: [Profile] = []
    @Published var activeProfile: Profile?
    
    private let profilesKey = "myclash_profiles"
    private let activeProfileKey = "myclash_active_profile"
    private let profilesDirectory: URL
    
    private init() {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            profilesDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("MyClash")
            return
        }
        
        let directory = appSupport.appendingPathComponent("MyClash")
        profilesDirectory = directory.appendingPathComponent("profiles")
        
        if !FileManager.default.fileExists(atPath: profilesDirectory.path) {
            try? FileManager.default.createDirectory(at: profilesDirectory, withIntermediateDirectories: true)
        }
        
        loadProfiles()
    }
    
    func loadProfiles() {
        if let data = UserDefaults.standard.data(forKey: profilesKey) {
            if let loadedProfiles = try? JSONDecoder().decode([Profile].self, from: data) {
                profiles = loadedProfiles
            }
        }
        
        if let activeID = UserDefaults.standard.string(forKey: activeProfileKey),
           let profile = profiles.first(where: { $0.id == activeID }) {
            activeProfile = profile
        } else if let defaultProfile = profiles.first(where: { $0.isDefault }) {
            activeProfile = defaultProfile
        } else if profiles.isEmpty {
            createDefaultProfile()
        }
    }
    
    private func createDefaultProfile() {
        let defaultContent = generateDefaultConfig()
        let profile = Profile(name: "default", content: defaultContent, isDefault: true)
        profiles.append(profile)
        activeProfile = profile
        saveProfiles()
    }
    
    private func generateDefaultConfig() -> String {
        return """
        port: 7890
        socks-port: 7891
        allow-lan: false
        mode: rule
        log-level: info
        ipv6: true
        
        tun:
          enable: true
          stack: gvisor
          dns-hijack:
            - any:53
            - icmp
            - 198.18.0.2
        
        dns:
          enable: true
          listen: 0.0.0.0:1053
          ipv6: false
          enhanced-mode: fake-ip
          fake-ip-range: 198.18.0.1
          fake-ip-filter:
            - "*.lan"
            - "*.local"
          default-nameserver:
            - 223.5.5.5
          nameserver:
            - https://dns.alidns.com/dns-query
            - https://doh.pub/dns-query
        
        proxies: []
        proxy-groups: []
        rules:
          - DOMAIN-SUFFIX,google.com,PROXY
          - DOMAIN-KEYWORD,.github.,PROXY
          - GEOSITE,cn,DIRECT
          - GEOIP,CN,DIRECT
          - MATCH,DIRECT
        """
    }
    
    func saveProfiles() {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: profilesKey)
        }
        
        if let active = activeProfile {
            UserDefaults.standard.set(active.id, forKey: activeProfileKey)
        }
        
        // Save profile content to file
        if let active = activeProfile {
            let fileURL = profilesDirectory.appendingPathComponent("\(active.id).yaml")
            try? active.content.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }
    
    func addProfile(name: String, url: String? = nil, content: String) {
        let isNewDefault = profiles.isEmpty
        let profile = Profile(name: name, url: url, content: content, isDefault: isNewDefault)
        profiles.append(profile)
        if isNewDefault {
            activeProfile = profile
        }
        saveProfiles()
    }
    
    func updateProfile(_ profile: Profile, content: String) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index].content = content
            profiles[index].updatedAt = Date()
            if activeProfile?.id == profile.id {
                activeProfile = profiles[index]
            }
            saveProfiles()
        }
    }
    
    func deleteProfile(_ profile: Profile) {
        profiles.removeAll(where: { $0.id == profile.id })
        if activeProfile?.id == profile.id {
            activeProfile = profiles.first(where: { $0.isDefault }) ?? profiles.first
        }
        saveProfiles()
        
        // Delete profile file
        let fileURL = profilesDirectory.appendingPathComponent("\(profile.id).yaml")
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    func setActiveProfile(_ profile: Profile) {
        activeProfile = profile
        for i in profiles.indices {
            profiles[i].isDefault = (profiles[i].id == profile.id)
        }
        saveProfiles()
    }
    
    func importProfileFromURL(url: String, completion: @escaping (Result<Profile, Error>) -> Void) {
        guard let profileURL = URL(string: url) else {
            completion(.failure(NSError(domain: "ProfileManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: profileURL)
        request.timeoutInterval = 30
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data, let content = String(data: data, encoding: .utf8) else {
                completion(.failure(NSError(domain: "ProfileManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response data"])))
                return
            }
            
            let name = profileURL.lastPathComponent.isEmpty ? profileURL.host ?? "Imported Profile" : profileURL.lastPathComponent
            DispatchQueue.main.async {
                let profile = Profile(name: name, url: url, content: content)
                completion(.success(profile))
            }
        }
        task.resume()
    }
    
    func getProfileFilePath(_ profile: Profile) -> String {
        return profilesDirectory.appendingPathComponent("\(profile.id).yaml").path
    }
}
