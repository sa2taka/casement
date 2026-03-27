import CoreGraphics

struct WindowStableID: Hashable, Sendable {
    let pid: pid_t
    let axIdentifier: String?
    let titleFingerprint: String
    let boundsFingerprint: String

    var stringRepresentation: String {
        "\(pid)|\(axIdentifier ?? "")|\(titleFingerprint)|\(boundsFingerprint)"
    }

    static func titleFingerprint(from title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let prefix = String(trimmed.prefix(64))
        return prefix.lowercased()
    }

    static func boundsFingerprint(from bounds: CGRect) -> String {
        "\(Int(bounds.origin.x)),\(Int(bounds.origin.y)),\(Int(bounds.width)),\(Int(bounds.height))"
    }
}
