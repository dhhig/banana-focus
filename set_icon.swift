import AppKit

let appPath = "/Applications/剥香蕉.app"
let iconPath = appPath + "/Contents/Resources/AppIcon.icns"

guard let icon = NSImage(contentsOfFile: iconPath) else {
    print("FAIL: Cannot load icon")
    exit(1)
}

let result = NSWorkspace.shared.setIcon(icon, forFile: appPath, options: [])
print(result ? "OK: icon set" : "FAIL: setIcon returned false")

// Also touch the app to refresh
let fm = FileManager.default
try? fm.setAttributes([.modificationDate: Date()], ofItemAtPath: appPath)
print("touched")
