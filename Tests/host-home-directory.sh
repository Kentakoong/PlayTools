#!/bin/bash
# Reproduce the Foundation home-directory override used by App Sandbox.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
cat > "$test_dir/main.swift" <<'SWIFT'
import Foundation

let home = playCoverHostHomeDirectoryPath()
if CommandLine.arguments.count == 1 {
    print(home)
    exit(0)
} else {
    precondition(NSHomeDirectory() != CommandLine.arguments[1], "Sandbox override was not applied")
    precondition(home == CommandLine.arguments[1], "Settings path incorrectly uses the game sandbox")
    print("PASS: sandbox override does not change PlayCover's settings home")
}

precondition(playCoverPreferredDisplayRotation(infoDictionary: [
    "UISupportedInterfaceOrientations~ipad": ["UIInterfaceOrientationPortrait"]
]) == 1)
precondition(playCoverPreferredDisplayRotation(infoDictionary: [
    "UISupportedInterfaceOrientations": ["UIInterfaceOrientationLandscapeRight"]
]) == 2)
precondition(playCoverPreferredDisplayRotation(infoDictionary: [:]) == 0)
print("PASS: automatic rotation follows the app's preferred declared orientation")

precondition(playCoverNeedsLaunchCompatibilityMigration(version: "2.0.0"))
precondition(playCoverNeedsLaunchCompatibilityMigration(version: "3.0.0"))
precondition(!playCoverNeedsLaunchCompatibilityMigration(version: "3.1.0"))
precondition(!playCoverNeedsLaunchCompatibilityMigration(version: "4.0.0"))
print("PASS: launch compatibility migration is version-bounded")
SWIFT
swiftc -module-cache-path "$test_dir/cache" "$repo_root/Plugin.swift" "$test_dir/main.swift" -o "$test_dir/check-home"
expected_home="$(env -u CFFIXED_USER_HOME "$test_dir/check-home")"
CFFIXED_USER_HOME="$test_dir/game-container/Data" "$test_dir/check-home" "$expected_home"
