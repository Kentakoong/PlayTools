#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
cat > "$test_dir/main.swift" <<'SWIFT'
import Foundation
import CoreGraphics
protocol MouseEventAdapter {}
struct Window { var bounds: CGRect }
class Screen {
    var resizable = false
    var fullscreen = false
    var screenRect = CGRect(x: 0, y: 0, width: 1024, height: 1366)
    var keyWindow: Window? = Window(bounds: CGRect(x: 0, y: 0, width: 1366, height: 1024))
}
let screen = Screen()
class Host {
    var mousePoint = CGPoint(x: 525.5, y: 394)
    var windowFrame = CGRect(x: 0, y: 0, width: 1051, height: 816)
    var windowContentSize = CGSize(width: 1051, height: 788)
}
enum AKInterface { static var shared: Host? = Host() }
enum Priority { case DRAGGABLE, OTHER }
enum ActionDispatcher {
    static func dispatch(key: String, valueX: CGFloat, valueY: CGFloat) -> Bool { false }
    static func dispatch(key: String, pressed: Bool) -> Bool { false }
    static func getDispatchPriority(key: String) -> Priority { .OTHER }
}
enum KeyCodeNames { static let scrollWheelDrag = "scroll", mouseMove = "move", fakeMouse = "mouse" }
enum EditorMouseEventAdapter { static func getMouseButtonName(_ id: Int) -> String { "mouse" } }
func expect(_ expected: CGPoint) {
    guard let actual = TouchscreenMouseEventAdapter.cursorPos(),
          abs(actual.x - expected.x) < 0.001, abs(actual.y - expected.y) < 0.001 else {
        print("FAIL: cursor maps to \(String(describing: TouchscreenMouseEventAdapter.cursorPos())) instead of \(expected)")
        exit(1)
    }
}
// Captured live: UIScreen remains portrait while UIWindow and host content rotate.
expect(CGPoint(x: 683, y: 512))
AKInterface.shared!.mousePoint = CGPoint(x: 105.1, y: 630.4)
expect(CGPoint(x: 136.6, y: 204.8))
AKInterface.shared!.mousePoint = CGPoint(x: 500, y: 800)
precondition(TouchscreenMouseEventAdapter.cursorPos() == nil, "title bar must not generate a touch")
screen.keyWindow!.bounds = CGRect(x: 0, y: 0, width: 1024, height: 1366)
AKInterface.shared!.windowContentSize = CGSize(width: 788, height: 1051)
AKInterface.shared!.windowFrame.size = CGSize(width: 788, height: 1079)
AKInterface.shared!.mousePoint = CGPoint(x: 394, y: 525.5)
expect(CGPoint(x: 512, y: 683))
print("PASS: actual cursor adapter matches UIKit in landscape and portrait")
SWIFT
swiftc -module-cache-path "$test_dir/cache" "$repo_root/PlayTools/Controls/Frontend/EventAdapter/Mouse/Instances/TouchscreenMouseEventAdapter.swift" "$test_dir/main.swift" -o "$test_dir/check"
"$test_dir/check"
