import Foundation

/// Loads keybind data from user config or bundled defaults.
///
/// Priority order:
/// 1. `~/.config/key/keybinds.json` (user custom)
/// 2. Bundled `default-keybinds.json` (app resource)
///
/// Falls back to bundled defaults on missing file or JSON parse errors.
///
/// @example
/// ```swift
/// let data = KeybindLoader.load()
/// for category in data.categories {
///     print(category.category, category.keybinds.count)
/// }
/// ```
enum KeybindLoader {
    static let userConfigPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.config/key/keybinds.json"
    }()

    /// Creates `~/.config/key/` directory and copies bundled defaults on first launch.
    ///
    /// Safe to call multiple times — skips if directory and file already exist.
    ///
    /// @example
    /// ```swift
    /// KeybindLoader.ensureUserConfigExists()
    /// // Creates ~/.config/key/keybinds.json from bundled defaults
    /// ```
    static func ensureUserConfigExists() {
        let configDir = URL(fileURLWithPath: userConfigPath).deletingLastPathComponent()
        let fm = FileManager.default

        if !fm.fileExists(atPath: configDir.path) {
            do {
                try fm.createDirectory(at: configDir, withIntermediateDirectories: true)
            } catch {
                print("[Key] Failed to create config directory: \(error)")
                return
            }
        }

        if !fm.fileExists(atPath: userConfigPath) {
            if let bundledURL = Bundle.module.url(forResource: "default-keybinds", withExtension: "json") {
                do {
                    try fm.copyItem(at: bundledURL, to: URL(fileURLWithPath: userConfigPath))
                } catch {
                    print("[Key] Failed to copy default keybinds: \(error)")
                }
            }
        }
    }

    /// Loads keybind data with user-config-first priority and default fallback.
    static func load() -> KeybindData {
        if let data = loadUserConfig() {
            return data
        }
        return loadBundledDefault()
    }

    /// Attempts to load and parse `~/.config/key/keybinds.json`.
    /// Returns nil if the file doesn't exist or fails to parse.
    private static func loadUserConfig() -> KeybindData? {
        let url = URL(fileURLWithPath: userConfigPath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(KeybindData.self, from: data)
        } catch {
            print("[Key] Failed to parse user keybinds at \(userConfigPath): \(error). Using defaults.")
            return nil
        }
    }

    /// Loads the bundled default keybinds JSON from app resources.
    /// Uses a hardcoded fallback if the bundle resource is somehow missing.
    private static func loadBundledDefault() -> KeybindData {
        guard let url = Bundle.module.url(forResource: "default-keybinds", withExtension: "json") else {
            print("[Key] Bundled default-keybinds.json not found. Using empty fallback.")
            return KeybindData(categories: [])
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(KeybindData.self, from: data)
        } catch {
            print("[Key] Failed to parse bundled default-keybinds.json: \(error). Using empty fallback.")
            return KeybindData(categories: [])
        }
    }
}
