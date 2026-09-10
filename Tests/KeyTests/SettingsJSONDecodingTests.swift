import Foundation
import XCTest

/// Mirrors {@link ShortcutConfig} so missing overlay fields stay optional after a settings upgrade.
private struct SettingsFile: Codable {
    var globalShortcut: String
    var fontSize: Double?
    var windowWidth: Double?
    var windowHeight: Double?
    var backgroundOpacity: Double?
    var alwaysOnTop: Bool?
    var selectedProfile: String?
}

/// Spec: existing `settings.json` files without opacity / pin / table keys must still decode.
final class SettingsJSONDecodingTests: XCTestCase {
    func testLegacySettingsJSONDecodesWithoutNewOverlayFields() throws {
        // Arrange
        let json = """
        {
          "globalShortcut": "⌘⇧K",
          "fontSize": 16,
          "windowWidth": 860,
          "windowHeight": 850
        }
        """.data(using: .utf8)!

        // Act
        let settings = try JSONDecoder().decode(SettingsFile.self, from: json)

        // Assert
        XCTAssertEqual(settings.globalShortcut, "⌘⇧K")
        XCTAssertEqual(settings.fontSize, 16)
        XCTAssertEqual(settings.windowWidth, 860)
        XCTAssertEqual(settings.windowHeight, 850)
        XCTAssertNil(settings.backgroundOpacity)
        XCTAssertNil(settings.alwaysOnTop)
        XCTAssertNil(settings.selectedProfile)
    }

    func testOverlaySettingsJSONRoundTripsOpacityPinAndProfile() throws {
        // Arrange
        let original = SettingsFile(
            globalShortcut: "⌘⌥K",
            fontSize: 18,
            windowWidth: 1000,
            windowHeight: 700,
            backgroundOpacity: 0.65,
            alwaysOnTop: true,
            selectedProfile: "emacs"
        )

        // Act
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SettingsFile.self, from: data)

        // Assert
        XCTAssertEqual(decoded.globalShortcut, "⌘⌥K")
        XCTAssertEqual(decoded.backgroundOpacity, 0.65)
        XCTAssertEqual(decoded.alwaysOnTop, true)
        XCTAssertEqual(decoded.selectedProfile, "emacs")
    }

    func testEachSelectedProfileHasABundledTableFile() throws {
        // Arrange
        let profileFiles = [
            "cursor": "default-keybinds.json",
            "emacs": "emacs-keybinds.json",
            "vim": "vim-keybinds.json",
            "github": "github-keybinds.json",
        ]
        let resources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Key/Resources")

        // Act / Assert
        XCTAssertEqual(Array(profileFiles.keys).sorted(), ["cursor", "emacs", "github", "vim"])
        for (profile, fileName) in profileFiles {
            let url = resources.appendingPathComponent(fileName)
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: url.path),
                "\(profile) is missing bundled table \(fileName)"
            )
        }
    }
}
