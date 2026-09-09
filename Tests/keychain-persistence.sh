#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
export PT_TEST_HOME="$test_dir/container"
printf 'import Foundation\nimport Security\n' > "$test_dir/Constants.swift"
cat "$repo_root/PlayTools/MysticRunes/PlayedAppleDBConstants.swift" >> "$test_dir/Constants.swift"
cat > "$test_dir/Support.swift" <<'SWIFT'
import Foundation
func playCoverContainerBaseURL() -> URL { URL(fileURLWithPath: ProcessInfo.processInfo.environment["PT_TEST_HOME"]!) }
class PlayKeychain { static func debugLogger(_ message: String) {} }
SWIFT
cat > "$test_dir/main.swift" <<'SWIFT'
import Foundation
import Security
let item: NSDictionary = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: "synthetic-account", kSecAttrService: "synthetic-login", kSecValueData: Data("test-token".utf8)]
if CommandLine.arguments[1] == "write" {
    guard PlayKeychainDB.shared.insert(item) != nil else { print("FAIL: first credential write failed"); exit(1) }
    print("PASS: credential stored")
} else {
    guard let found = PlayKeychainDB.shared.query(item)?.first, found[kSecValueData] as? Data == Data("test-token".utf8) else { print("FAIL: credential lost across process restart"); exit(1) }
    print("PASS: credential survives process restart")
}
SWIFT
swiftc -module-cache-path "$test_dir/cache" "$test_dir/Constants.swift" "$test_dir/Support.swift" \
    "$repo_root/PlayTools/MysticRunes/PlayedAppleDB.swift" "$test_dir/main.swift" -o "$test_dir/check"
"$test_dir/check" write
"$test_dir/check" read
