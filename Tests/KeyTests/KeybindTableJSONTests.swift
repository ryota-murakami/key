import Foundation
import XCTest

/// Decodes bundled keybind tables the same way {@link KeybindLoader} does, without importing the app target.
private struct KeybindFile: Decodable {
    let categories: [Category]

    struct Category: Decodable {
        let category: String
        let keybinds: [Bind]
    }

    struct Bind: Decodable {
        let action: String
        let shortcut: String
    }
}

/// Spec: every shipped keybind table must decode and stay non-empty so overlay switching cannot show a blank board.
final class KeybindTableJSONTests: XCTestCase {
    func testCursorTableDecodesWithExpectedCategories() throws {
        // Arrange
        let url = try resourceURL(named: "default-keybinds")

        // Act
        let file = try decode(url)

        // Assert
        XCTAssertEqual(
            file.categories.map(\.category),
            [
                "Move Cursor",
                "Selection",
                "Scroll",
                "Code Edit",
                "Find",
                "Split Editor Window",
                "Code Jump",
                "IntelliSense",
                "File Explorer",
                "IDE Feature",
                "AI",
                "Git",
                "Multiple Cursor",
            ]
        )
        XCTAssertEqual(file.categories.flatMap(\.keybinds).count, 98)
        try assertNoEmptyRows(in: file, table: "Cursor")
    }

    func testEmacsTableDecodesWithExpectedCategories() throws {
        // Arrange
        let url = try resourceURL(named: "emacs-keybinds")

        // Act
        let file = try decode(url)

        // Assert
        XCTAssertEqual(
            file.categories.map(\.category),
            [
                "Motion",
                "Editing",
                "Kill & Yank",
                "Region",
                "Search",
                "Files",
                "Buffers",
                "Windows",
                "Scroll",
                "Commands & Help",
                "Code",
                "Registers & Macros",
            ]
        )
        XCTAssertEqual(file.categories.flatMap(\.keybinds).count, 86)
        try assertNoEmptyRows(in: file, table: "Emacs")
    }

    func testVimTableDecodesWithExpectedCategories() throws {
        // Arrange
        let url = try resourceURL(named: "vim-keybinds")

        // Act
        let file = try decode(url)

        // Assert
        XCTAssertEqual(
            file.categories.map(\.category),
            [
                "Motion",
                "Word & Line",
                "Insert",
                "Edit",
                "Yank & Put",
                "Visual",
                "Search",
                "Scroll",
                "Windows",
                "Files & Buffers",
                "Marks & Jumps",
                "Macros & Registers",
            ]
        )
        XCTAssertEqual(file.categories.flatMap(\.keybinds).count, 103)
        try assertNoEmptyRows(in: file, table: "Vim")
    }

    func testGitHubTableDecodesWithExpectedCategories() throws {
        // Arrange
        let url = try resourceURL(named: "github-keybinds")

        // Act
        let file = try decode(url)

        // Assert
        XCTAssertEqual(
            file.categories.map(\.category),
            [
                "Site Wide",
                "Repositories",
                "Source Code Browse",
                "Source Code Edit",
                "Markdown",
                "Issue & PR Lists",
                "Issues & Pull Requests",
                "Comments",
                "Files Changed",
                "Notifications",
                "Actions",
                "Projects",
            ]
        )
        XCTAssertEqual(file.categories.flatMap(\.keybinds).count, 84)
        try assertNoEmptyRows(in: file, table: "GitHub")
    }

    /// Fails when any category or shortcut row is blank — that would render as an empty overlay block.
    private func assertNoEmptyRows(in file: KeybindFile, table: String) throws {
        for category in file.categories {
            XCTAssertFalse(category.category.isEmpty, "\(table) has an unnamed category")
            XCTAssertFalse(category.keybinds.isEmpty, "\(table) category \(category.category) has no keybinds")
            for bind in category.keybinds {
                XCTAssertFalse(bind.action.isEmpty, "\(table) has a blank action in \(category.category)")
                XCTAssertFalse(bind.shortcut.isEmpty, "\(table) has a blank shortcut for \(bind.action)")
            }
        }
    }

    /// Resolves `Sources/Key/Resources/<name>.json` from this test file's location.
    private func resourceURL(named name: String) throws -> URL {
        let testsDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let url = testsDir
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Key/Resources/\(name).json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "Missing \(url.path)")
        return url
    }

    private func decode(_ url: URL) throws -> KeybindFile {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(KeybindFile.self, from: data)
    }
}
