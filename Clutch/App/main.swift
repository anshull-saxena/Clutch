import AppKit

print("main.swift: Starting NSApplication setup")
let app = NSApplication.shared
print("main.swift: Instantiating AppDelegate")
let delegate = AppDelegate()
app.delegate = delegate
print("main.swift: Setting activation policy")
app.setActivationPolicy(.accessory)
print("main.swift: Running event loop")
app.run()
print("main.swift: Event loop exited")

