import Foundation
import AppKit
import CoreGraphics

/// Manages fullscreen overlay windows that dim everything except whitelisted app windows.
class FocusOverlayService {

    var opacity: CGFloat = 0.65 {
        didSet {
            for (_, overlay) in overlayWindows {
                overlay.alphaValue = opacity
            }
        }
    }

    private var overlayWindows: [CGDirectDisplayID: FocusOverlayWindow] = [:]
    private var whitelistedBundleIDs: Set<String> = []
    private var isShowing = false

    // MARK: - Public API

    func show(whitelistedBundleIDs: Set<String>) {
        self.whitelistedBundleIDs = whitelistedBundleIDs
        self.isShowing = true

        // Create overlay for each active display
        var displayCount: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &displayCount) == .success else { return }

        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        guard CGGetActiveDisplayList(displayCount, &displays, &displayCount) == .success else { return }

        for displayID in displays {
            createOverlay(for: displayID)
        }

        // Listen for display configuration changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDisplayReconfig),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func hide() {
        isShowing = false
        NotificationCenter.default.removeObserver(
            self,
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        for (_, window) in overlayWindows {
            window.orderOut(nil)
            window.close()
        }
        overlayWindows.removeAll()
    }

    func refreshCutouts() {
        guard isShowing else { return }
        let studyWindowRects = getStudyAppWindowRects()

        for (displayID, window) in overlayWindows {
            let displayBounds = CGDisplayBounds(displayID)

            // Find study windows on this display
            var windowsOnDisplay: [CGRect] = []
            for rect in studyWindowRects {
                if displayBounds.intersects(rect) {
                    // Convert from CG coordinates to display-local coordinates
                    var localRect = rect
                    localRect.origin.x -= displayBounds.origin.x
                    localRect.origin.y -= displayBounds.origin.y
                    windowsOnDisplay.append(localRect)
                }
            }

            // Update the overlay view's cutouts
            if let overlayView = window.contentView as? FocusOverlayView {
                overlayView.updateCutouts(windowsOnDisplay)
            }
        }
    }

    // MARK: - Private

    private func createOverlay(for displayID: CGDirectDisplayID) {
        // Skip if already exists
        guard overlayWindows[displayID] == nil else { return }

        let displayBounds = CGDisplayBounds(displayID)

        let window = FocusOverlayWindow(
            contentRect: NSRect(
                x: displayBounds.origin.x,
                y: displayBounds.origin.y,
                width: displayBounds.width,
                height: displayBounds.height
            ),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)))
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle,
        ]
        window.isReleasedWhenClosed = false
        window.alphaValue = opacity

        let overlayView = FocusOverlayView(frame: window.contentView?.bounds ?? NSRect.zero)
        overlayView.wantsLayer = true
        overlayView.layer?.drawsAsynchronously = true
        window.contentView = overlayView

        window.orderFront(nil)

        overlayWindows[displayID] = window
    }

    @objc private func handleDisplayReconfig(_ notification: Notification) {
        guard isShowing else { return }
        // Refresh overlays on next cutout update
        refreshOverlaysForCurrentDisplays()
    }

    private func refreshOverlaysForCurrentDisplays() {
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &displayCount)
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        CGGetActiveDisplayList(displayCount, &displays, &displayCount)

        let currentIDs = Set(displays)
        let existingIDs = Set(overlayWindows.keys)

        // Remove overlays for disconnected displays
        for id in existingIDs.subtracting(currentIDs) {
            overlayWindows[id]?.close()
            overlayWindows.removeValue(forKey: id)
        }

        // Add overlays for new displays
        for id in currentIDs.subtracting(existingIDs) {
            createOverlay(for: id)
        }
    }

    /// Use CGWindowListCopyWindowInfo to get windows belonging to whitelisted apps.
    private func getStudyAppWindowRects() -> [CGRect] {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }

        // First, find the PIDs for our whitelisted bundle IDs
        let studyPIDs = getStudyAppPIDs()

        var rects: [CGRect] = []

        for windowInfo in windowList {
            guard let pid = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                  studyPIDs.contains(pid) else { continue }

            // Skip very small windows (likely palettes, popovers)
            guard let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = boundsDict["X"], let y = boundsDict["Y"],
                  let w = boundsDict["Width"], let h = boundsDict["Height"] else { continue }

            // Skip tiny windows or menus
            if w < 100 || h < 100 { continue }

            // Skip windows with certain layer levels (like menus or tooltips)
            if let layer = windowInfo[kCGWindowLayer as String] as? Int32, layer > 1000 {
                continue
            }

            let rect = CGRect(x: x, y: y, width: w, height: h)
            rects.append(rect)
        }

        // Merge overlapping or nearby rects? For now, return them individually.
        return rects
    }

    private func getStudyAppPIDs() -> Set<pid_t> {
        var pids = Set<pid_t>()
        let apps = NSWorkspace.shared.runningApplications
        for app in apps {
            if let bundleID = app.bundleIdentifier,
               whitelistedBundleIDs.contains(bundleID) {
                pids.insert(app.processIdentifier)
            }
        }
        return pids
    }
}

// MARK: - Overlay Window

class FocusOverlayWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - Overlay View

class FocusOverlayView: NSView {

    private var cutoutRects: [CGRect] = []
    private let cutoutPadding: CGFloat = 12
    private let cornerRadius: CGFloat = 16

    func updateCutouts(_ rects: [CGRect]) {
        let paddedRects = rects.map { $0.insetBy(dx: -cutoutPadding, dy: -cutoutPadding) }
        // Only redraw if changed
        guard paddedRects != cutoutRects else { return }
        cutoutRects = paddedRects
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Draw dark overlay using a path with holes (even-odd winding)
        let path = NSBezierPath(rect: bounds)

        for rect in cutoutRects {
            let holePath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
            path.append(holePath)
        }

        path.windingRule = .evenOdd

        // Semi-transparent dark fill
        NSColor.black.withAlphaComponent(0.65).setFill()
        path.fill()

        // Draw soft shadow/glow around cutouts for a polished look
        for rect in cutoutRects {
            let shadowPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
            NSColor.white.withAlphaComponent(0.08).setStroke()
            shadowPath.lineWidth = 2
            shadowPath.stroke()
        }
    }
}

// Notifications are handled via UserNotifications framework in SessionManager
