import XCTest
@testable import MultiCoding

final class AntigravityHistoryTests: XCTestCase {
    func testHistoryPreservesResumeIdentityAndExcludesSubagents() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let database = directory.appendingPathComponent("conversations.db")
        let id = "11111111-2222-3333-4444-555555555555"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [database.path, """
        CREATE TABLE conversation_summaries (conversation_id TEXT, title TEXT, preview TEXT, workspace_uris TEXT, last_modified_time TEXT, parent_conversation_id TEXT);
        INSERT INTO conversation_summaries VALUES ('\(id)', 'Project task', '', '["file:///tmp/My%20Project"]', '2026-11-01 12:00:00+00:00', '');
        INSERT INTO conversation_summaries VALUES ('aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee', 'Child', '', '[]', '2026-11-01 13:00:00+00:00', '\(id)');
        """]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
        let sessions = try AntigravityConversation.load(databaseURL: database)
        XCTAssertEqual(sessions.count, 1)
        let session = try XCTUnwrap(sessions.first)
        XCTAssertEqual(session.id, id)
        XCTAssertEqual(session.cwd, "/tmp/My Project")
        XCTAssertEqual(session.name, "Project task")
        XCTAssertEqual(session.date.timeIntervalSince1970, 1793534400, accuracy: 1)
    }
}
