import Foundation

/// Loads a {@link KeybindProfile} table from user config or bundled defaults.
///
/// Priority per profile:
/// 1. `~/.config/key/{@link KeybindProfile.userFileName}`
/// 2. Bundled `{@link KeybindProfile.bundledResourceName}.json`
///
/// Falls back to bundled defaults on a missing file or JSON parse error.
///
/// @example
/// ```swift
/// let data = KeybindLoader.load(profile: .emacs)
/// KeybindLoader.ensureUserConfigExists()
/// ```
enum KeybindLoader {
    /// Directory that holds every per-profile JSON file.
    static var userConfigDirectory: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.config/key"
    }

    /// User JSON path for the currently selected table — used by Edit Keybinds.
    static var userConfigPath: String {
        userConfigPath(for: SettingsStore.shared.selectedProfile)
    }

    /// User JSON path for a specific {@link KeybindProfile}.
    ///
    /// - Parameter profile: Table whose override file should be opened or loaded.
    /// - Returns: Absolute path under `~/.config/key/`.
    static func userConfigPath(for profile: KeybindProfile) -> String {
        "\(userConfigDirectory)/\(profile.userFileName)"
    }

    /// Creates `~/.config/key/` and copies any missing bundled profile files.
    ///
    /// Safe to call multiple times — existing user files are left untouched so Cursor
    /// customizations in `keybinds.json` survive adding Emacs / Vim / GitHub tables.
    ///
    /// @example
    /// ```swift
    /// KeybindLoader.ensureUserConfigExists()
    /// ```
    static func ensureUserConfigExists() {
        let fm = FileManager.default
        let configDir = URL(fileURLWithPath: userConfigDirectory)

        if !fm.fileExists(atPath: configDir.path) {
            do {
                try fm.createDirectory(at: configDir, withIntermediateDirectories: true)
            } catch {
                print("[Key] Failed to create config directory: \(error)")
                return
            }
        }

        // Copy each bundled table only when the user override is absent.
        for profile in KeybindProfile.allCases {
            let destination = URL(fileURLWithPath: userConfigPath(for: profile))
            guard !fm.fileExists(atPath: destination.path) else { continue }
            guard let bundledURL = Bundle.module.url(
                forResource: profile.bundledResourceName,
                withExtension: "json"
            ) else { continue }

            do {
                try fm.copyItem(at: bundledURL, to: destination)
            } catch {
                print("[Key] Failed to copy \(profile.userFileName): \(error)")
            }
        }
    }

    /// Loads keybind data for a profile with user-config-first priority.
    ///
    /// - Parameter profile: Table to load; defaults to the saved selection.
    /// - Returns: Decoded categories, or an empty container if both sources fail.
    static func load(profile: KeybindProfile = SettingsStore.shared.selectedProfile) -> KeybindData {
        if let data = loadUserConfig(profile: profile) {
            return data
        }
        return loadBundled(profile: profile)
    }

    /// Attempts to load and parse the user override for `profile`.
    ///
    /// - Parameter profile: Table whose `~/.config/key/` file should be read.
    /// - Returns: Decoded data, or `nil` when the file is missing or invalid.
    private static func loadUserConfig(profile: KeybindProfile) -> KeybindData? {
        let url = URL(fileURLWithPath: userConfigPath(for: profile))
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(KeybindData.self, from: data)
        } catch {
            print("[Key] Failed to parse \(url.path): \(error). Using bundled \(profile.rawValue).")
            return nil
        }
    }

    /// Loads the bundled JSON for `profile`, then Cursor defaults, then empty data.
    ///
    /// - Parameter profile: Table whose bundled resource should be decoded.
    /// - Returns: The first successfully decoded bundled table.
    private static func loadBundled(profile: KeybindProfile) -> KeybindData {
        if let data = decodeBundledResource(profile.bundledResourceName) {
            return data
        }
        // Last-resort fallback so a missing Emacs/Vim/GitHub resource still shows Cursor binds.
        if profile != .cursor, let data = decodeBundledResource(KeybindProfile.cursor.bundledResourceName) {
            return data
        }
        print("[Key] Bundled \(profile.bundledResourceName).json not found. Using empty fallback.")
        return KeybindData(categories: [])
    }

    /// Decodes a bundled JSON resource by file name (without extension).
    ///
    /// - Parameter resourceName: Resource stem such as `emacs-keybinds`.
    /// - Returns: Decoded {@link KeybindData}, or `nil` on missing file / parse error.
    private static func decodeBundledResource(_ resourceName: String) -> KeybindData? {
        guard let url = Bundle.module.url(forResource: resourceName, withExtension: "json") else {
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(KeybindData.self, from: data)
        } catch {
            print("[Key] Failed to parse bundled \(resourceName).json: \(error).")
            return nil
        }
    }
}
