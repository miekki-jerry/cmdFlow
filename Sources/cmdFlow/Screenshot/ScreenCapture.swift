import AppKit
import ScreenCaptureKit

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}

/// Captures a screen region via ScreenCaptureKit (requires Screen Recording permission).
enum ScreenCapture {
    enum CaptureError: LocalizedError {
        case permissionDenied
        case noDisplay
        case failed

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Screen Recording permission is required. Enable it in System Settings → Privacy & Security → Screen Recording."
            case .noDisplay:
                return "Couldn't find the display to capture."
            case .failed:
                return "Screenshot capture failed."
            }
        }
    }

    /// Captures `rect` (global AppKit coordinates, bottom-left origin) on the given display.
    /// Takes primitive Sendable values so it can be called off the main actor safely.
    static func capture(globalRect rect: CGRect, displayID: CGDirectDisplayID,
                        screenFrame frame: CGRect, scale: CGFloat) async throws -> NSImage {
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            throw CaptureError.permissionDenied
        }

        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw CaptureError.noDisplay
        }

        // AppKit global (bottom-left) → display-local top-left points.
        let localX = rect.origin.x - frame.origin.x
        let localYTop = (frame.origin.y + frame.height) - (rect.origin.y + rect.height)
        let sourceRect = CGRect(x: localX, y: localYTop, width: rect.width, height: rect.height)

        let config = SCStreamConfiguration()
        config.sourceRect = sourceRect
        config.width = max(1, Int(rect.width * scale))
        config.height = max(1, Int(rect.height * scale))
        config.showsCursor = false

        let filter = SCContentFilter(display: display, excludingWindows: [])
        do {
            let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            return NSImage(cgImage: cgImage, size: NSSize(width: rect.width, height: rect.height))
        } catch {
            throw CaptureError.failed
        }
    }

    /// Base64-encoded PNG of an image (for vision API image_url data URLs).
    static func pngBase64(_ image: NSImage) -> String? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:])
        else { return nil }
        return png.base64EncodedString()
    }
}
