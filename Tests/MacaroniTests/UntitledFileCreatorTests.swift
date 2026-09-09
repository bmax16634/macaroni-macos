import XCTest
@testable import Macaroni

final class UntitledFileCreatorTests: XCTestCase {
    func testCreatesEmptyUntitledFile() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let file = try UntitledFileCreator.create(in: directory)

        XCTAssertEqual(file.lastPathComponent, "untitled")
        XCTAssertEqual(try Data(contentsOf: file), Data())
    }

    func testUsesNextAvailableUntitledName() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("keep".utf8).write(to: directory.appendingPathComponent("untitled"))
        try Data("keep too".utf8).write(to: directory.appendingPathComponent("untitled 2"))

        let file = try UntitledFileCreator.create(in: directory)

        XCTAssertEqual(file.lastPathComponent, "untitled 3")
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("untitled")), Data("keep".utf8))
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("macaroni-new-file-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        return directory
    }
}
