import Foundation

/// Keeps existing MultiCoding installs working across the original internal naming scheme.
enum LegacyCompatibility {
    static func copySupportDirectoryIfNeeded(base: URL, destination: URL, isBeta: Bool) {
        let oldName = isBeta ? "omux-beta" : "omux"
        let source = base.appendingPathComponent(oldName, isDirectory: true)
        guard !FileManager.default.fileExists(atPath: destination.path),
              FileManager.default.fileExists(atPath: source.path) else { return }
        try? FileManager.default.copyItem(at: source, to: destination)
    }

    static func importPreferences(keys: [String], isBeta: Bool) {
        let flag = "importedOmuxSettings"
        guard Bundle.main.bundleIdentifier?.hasPrefix("com.emreaykutalp.multicoding") == true,
              !UserDefaults.standard.bool(forKey: flag),
              let legacy = UserDefaults(suiteName: isBeta ? "net.pf1.omux.beta" : "net.pf1.omux") else { return }
        for key in keys where UserDefaults.standard.object(forKey: key) == nil {
            if let value = legacy.object(forKey: key) { UserDefaults.standard.set(value, forKey: key) }
        }
        UserDefaults.standard.set(true, forKey: flag)
    }

    static func setRepositoryEnvironment(_ environment: inout [String: String], repository: String) {
        environment["MULTICODING_REPO"] = repository
        // Saved setup commands from earlier releases may still use this variable.
        environment["OMUX_REPO"] = repository
    }
}
