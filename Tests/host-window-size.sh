#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
cat > "$test_dir/main.swift" <<'SWIFT'
import AppKit
let content = NSView(frame: NSRect(x: 0, y: 0, width: 788, height: 1051))
let scene = NSView(frame: content.bounds)
content.addSubview(scene)
scene.translatesAutoresizingMaskIntoConstraints = false
let width = scene.widthAnchor.constraint(equalToConstant: 788)
let height = scene.heightAnchor.constraint(equalToConstant: 1051)
width.priority = NSLayoutConstraint.Priority(rawValue: 980)
height.priority = NSLayoutConstraint.Priority(rawValue: 980)
let maximum = scene.widthAnchor.constraint(lessThanOrEqualToConstant: 3360)
NSLayoutConstraint.activate([width, height, maximum])
playCoverUpdateHostSizeConstraints(content, to: NSSize(width: 1051, height: 788))
guard width.constant == 1051 && height.constant == 788 else {
    print("FAIL: host constraints still restore the portrait frame after landscape resize")
    exit(1)
}
precondition(maximum.constant == 3360)
content.setFrameSize(NSSize(width: 1051, height: 788))
scene.setFrameSize(content.bounds.size)
playCoverUpdateHostSizeConstraints(content, to: NSSize(width: 788, height: 1051))
precondition(width.constant == 788 && height.constant == 1051)
print("PASS: hosted size constraints follow rotation in both directions")
SWIFT
swiftc -module-cache-path "$test_dir/cache" "$repo_root/Plugin.swift" "$repo_root/AKPlugin.swift" "$test_dir/main.swift" -o "$test_dir/check"
"$test_dir/check"
