import AppKit

// Entry point. We set the activation policy to `.accessory` so the app runs as
// a background menu-bar agent (no Dock icon, no main menu bar). This also works
// when running the raw executable outside an .app bundle; the Info.plist's
// LSUIElement=true does the same for the bundled app.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
