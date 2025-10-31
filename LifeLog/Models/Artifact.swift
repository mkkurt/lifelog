import Foundation

/// Represents an output artifact (file save, commit, etc.)
struct Artifact: Identifiable, Codable {
    let id: Int64
    let timestamp: Date
    let type: ArtifactType
    let appName: String
    let path: String?
    let metadata: [String: String]?

    init(
        id: Int64 = 0,
        timestamp: Date = Date(),
        type: ArtifactType,
        appName: String,
        path: String? = nil,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.appName = appName
        self.path = path
        self.metadata = metadata
    }
}

enum ArtifactType: String, Codable, CaseIterable {
    case fileSave = "file_save"
    case gitCommit = "git_commit"
    case export = "export"
    case note = "note"
    case completedTask = "completed_task"
    case email = "email"
    case message = "message"
    case screenshot = "screenshot"

    var displayName: String {
        switch self {
        case .fileSave: return "File Saved"
        case .gitCommit: return "Git Commit"
        case .export: return "Export"
        case .note: return "Note Created"
        case .completedTask: return "Task Completed"
        case .email: return "Email Sent"
        case .message: return "Message Sent"
        case .screenshot: return "Screenshot"
        }
    }

    var icon: String {
        switch self {
        case .fileSave: return "doc.fill"
        case .gitCommit: return "arrow.triangle.branch"
        case .export: return "square.and.arrow.up"
        case .note: return "note.text"
        case .completedTask: return "checkmark.circle"
        case .email: return "envelope"
        case .message: return "message"
        case .screenshot: return "camera"
        }
    }
}
