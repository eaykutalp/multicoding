import Foundation

enum RecentConversation: Identifiable {
    case claude(RecentSession), codex(CodexConversation), antigravity(AntigravityConversation)

    var id: String {
        switch self {
        case .claude(let session): return "claude:" + session.id.uuidString.lowercased()
        case .codex(let session): return "codex:" + session.id
        case .antigravity(let session): return "antigravity:" + session.id
        }
    }
    var cwd: String {
        switch self { case .claude(let s): return s.cwd; case .codex(let s): return s.cwd; case .antigravity(let s): return s.cwd }
    }
    var folder: String { (cwd as NSString).abbreviatingWithTildeInPath }
    var prompt: String {
        switch self { case .claude(let s): return s.prompt; case .codex(let s): return s.name; case .antigravity(let s): return s.name }
    }
    var date: Date {
        switch self { case .claude(let s): return s.date; case .codex(let s): return s.date; case .antigravity(let s): return s.date }
    }
}

struct AntigravityConversation: Identifiable {
    let id: String
    let cwd: String
    let name: String
    let date: Date

    static func load(databaseURL: URL = URL(fileURLWithPath: NSHomeDirectory() + "/.gemini/antigravity-cli/conversation_summaries.db")) throws -> [AntigravityConversation] {
        let path = databaseURL.path
        guard FileManager.default.fileExists(atPath: path) else { return [] }
        let query = "SELECT conversation_id, title, preview, workspace_uris, strftime('%s',last_modified_time) AS modified FROM conversation_summaries WHERE parent_conversation_id = '' ORDER BY last_modified_time DESC LIMIT 300;"
        func read(_ database: String) throws -> Data {
            let process = Process(), output = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
            process.arguments = ["-readonly", "-json", database, query]
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                throw NSError(domain: "AntigravityHistory", code: 1, userInfo: [NSLocalizedDescriptionKey: "Couldn't read Antigravity conversation history."])
            }
            return data
        }
        let data: Data
        do { data = try read(path) }
        catch {
            // Some CLI installations do not permit SQLite's shared-memory setup.
            // Fall back to the last committed database snapshot without writing to it.
            let uri = URL(fileURLWithPath: path).absoluteString + "?immutable=1"
            data = try read(uri)
        }
        guard !data.isEmpty else { return [] }
        let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
        return rows.compactMap { row in
            guard let id = row["conversation_id"] as? String, UUID(uuidString: id) != nil else { return nil }
            let encoded = (row["workspace_uris"] as? String ?? "[]").data(using: .utf8)!
            let uris = (try? JSONSerialization.jsonObject(with: encoded)) as? [String] ?? []
            let cwd = uris.compactMap { URL(string: $0) }.first(where: { $0.isFileURL })?.path ?? NSHomeDirectory()
            let title = (row["title"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let preview = (row["preview"] as? String ?? "").replacingOccurrences(of: "\n", with: " ")
            return AntigravityConversation(id: id, cwd: cwd, name: title.isEmpty ? (preview.isEmpty ? "Antigravity conversation" : preview) : title,
                date: Date(timeIntervalSince1970: Double(row["modified"] as? String ?? "0") ?? 0))
        }
    }
}

/// A Claude Code conversation found in ~/.claude/projects.
struct RecentSession: Identifiable, Hashable {
    let id: UUID
    let cwd: String
    let prompt: String
    let date: Date

    var folder: String { (cwd as NSString).abbreviatingWithTildeInPath }

    /// Short name for a tab: first words of the first prompt.
    var tabName: String {
        let words = prompt.split(separator: " ").prefix(5).joined(separator: " ")
        return words.count > 32 ? String(words.prefix(32)) + "…" : words
    }

    private struct Record: Decodable {
        struct Message: Decodable {
            let content: Content?
            enum Content: Decodable {
                case text(String), blocks([Block])
                struct Block: Decodable { let text: String? }
                init(from decoder: Decoder) throws {
                    let c = try decoder.singleValueContainer()
                    if let s = try? c.decode(String.self) { self = .text(s) } else { self = .blocks(try c.decode([Block].self)) }
                }
                var text: String {
                    switch self {
                    case .text(let s): return s
                    case .blocks(let b): return b.compactMap(\.text).joined(separator: " ")
                    }
                }
            }
        }
        let type: String
        let cwd: String?
        /// Claude Code's own text in a user record, e.g. a skill's instructions after its slash command.
        let isMeta: Bool?
        let message: Message?
    }

    /// Scans transcripts, newest first. Reads only the head of each file.
    static func load(limit: Int = 300) -> [RecentSession] {
        let root = URL(fileURLWithPath: NSHomeDirectory() + "/.claude/projects")
        let fm = FileManager.default
        guard let projects = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return [] }
        var files: [(URL, Date)] = []
        for project in projects {
            guard let items = try? fm.contentsOfDirectory(at: project, includingPropertiesForKeys: [.contentModificationDateKey]) else { continue }
            for url in items where url.pathExtension == "jsonl" {
                let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                files.append((url, date))
            }
        }
        files.sort { $0.1 > $1.1 }
        let decoder = JSONDecoder()
        var result: [RecentSession] = []
        for (url, date) in files.prefix(limit) {
            guard let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent),
                  let handle = try? FileHandle(forReadingFrom: url) else { continue }
            let head = handle.readData(ofLength: 128 * 1024)
            try? handle.close()
            // Lossy: the cut can split a character, which only spoils the (partial) last line.
            let text = String(decoding: head, as: UTF8.self)
            // Claude Code's own text (isMeta) only stands in when the user typed nothing else.
            var found: (cwd: String, prompt: String)?
            for line in text.split(separator: "\n") {
                guard let record = try? decoder.decode(Record.self, from: Data(line.utf8)),
                      record.type == "user",
                      let cwd = record.cwd,
                      let prompt = record.message?.content?.text.trimmingCharacters(in: .whitespacesAndNewlines),
                      !prompt.isEmpty, !prompt.hasPrefix("<") // skip slash-command and system messages
                else { continue }
                if record.isMeta == true {
                    if found == nil { found = (cwd, prompt) }
                    continue
                }
                found = (cwd, prompt)
                break
            }
            if let found {
                result.append(RecentSession(id: id, cwd: found.cwd, prompt: found.prompt.replacingOccurrences(of: "\n", with: " "), date: date))
            }
        }
        return result
    }
}
