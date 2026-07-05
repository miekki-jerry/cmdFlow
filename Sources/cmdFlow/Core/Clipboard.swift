import AppKit

enum Clipboard {
    static func readString() -> String? {
        NSPasteboard.general.string(forType: .string)
    }

    static func writeString(_ value: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(value, forType: .string)
    }
}
