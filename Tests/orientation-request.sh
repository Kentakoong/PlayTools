#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
cat > "$test_dir/main.swift" <<'SWIFT'
import Foundation
// Captured from Gakuen Idolmaster at Tap to Start: UIKit remains portrait
// while UnityDefaultViewController requests landscapeRight exclusively.
guard playCoverRequestedOrientation(sceneOrientation: 1, supportedOrientations: 8) == 3 else {
    print("FAIL: Unity's landscape request is hidden by the old portrait scene")
    exit(1)
}
guard playCoverRequestedOrientation(sceneOrientation: 3, supportedOrientations: 2) == 1 else {
    print("FAIL: returning from playback leaves the scene in landscape")
    exit(1)
}
precondition(playCoverRequestedOrientation(sceneOrientation: 3, supportedOrientations: 30) == 3)
precondition(playCoverRequestedOrientation(sceneOrientation: 0, supportedOrientations: 0) == nil)
precondition(playCoverRequestedOrientation(sceneOrientation: 0, supportedOrientations: 4) == 2)
print("PASS: game orientation requests override stale scene state in both directions")
SWIFT
swiftc -module-cache-path "$test_dir/cache" "$repo_root/Plugin.swift" "$test_dir/main.swift" -o "$test_dir/check"
"$test_dir/check"
