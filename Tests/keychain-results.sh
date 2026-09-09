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
class PlaySettings {
    static let shared = PlaySettings()
    let settingsData = SettingsData()
    struct SettingsData { let playChainDebugging = false }
}
SWIFT
cat > "$test_dir/main.swift" <<'SWIFT'
import Foundation
import Security
import SQLite3
let service = "synthetic-firebase-auth"
for index in 0..<3 {
    let attributes: NSDictionary = [kSecClass: kSecClassGenericPassword,
        kSecAttrAccount: "account-\(index)", kSecAttrService: service,
        kSecValueData: Data("synthetic-token-\(index)".utf8)]
    precondition(PlayKeychain.add(attributes, result: nil) == errSecSuccess)
}
// Older databases can contain the same logical item under different signing
// groups. Keep the data intact, but expose only the latest logical item.
let dbURL = try FileManager.default.contentsOfDirectory(
    at: playCoverContainerBaseURL().appendingPathComponent("PlayChain"),
    includingPropertiesForKeys: nil).first { $0.pathExtension == "db" }!
var db: OpaquePointer?
precondition(sqlite3_open(dbURL.path, &db) == SQLITE_OK)
precondition(sqlite3_exec(db, "INSERT INTO genp (agrp,acct,svce,v_Data) SELECT 'old-team',acct,svce,v_Data FROM genp WHERE acct='account-0'", nil, nil, nil) == SQLITE_OK)
sqlite3_close(db)
// Firebase Auth 12.10 requests data + attributes with numeric limit 2.
// It treats a single dictionary returned with success as a keychain error.
let query: NSMutableDictionary = [kSecClass: kSecClassGenericPassword,
    kSecAttrService: service, kSecReturnData: true, kSecReturnAttributes: true,
    kSecMatchLimit: 2]
var result: Unmanaged<CFTypeRef>?
let status = PlayKeychain.copyMatching(query, result: &result)
guard status == errSecSuccess,
      let items = result?.takeRetainedValue() as? [[String: Any]],
      items.count == 2, items.allSatisfy({ $0[kSecValueData as String] is Data }) else {
    print("FAIL: Firebase's numeric-limit query did not return two attribute dictionaries with saved data")
    exit(1)
}
query[kSecMatchLimit] = kSecMatchLimitAll
result = nil
precondition(PlayKeychain.copyMatching(query, result: &result) == errSecSuccess)
let all = result!.takeRetainedValue() as! [[String: Any]]
guard all.count == 3 && all.allSatisfy({ $0[kSecValueData as String] is Data }) else {
    print("FAIL: legacy signing-group duplicates appeared as separate saved accounts")
    exit(1)
}
query[kSecReturnAttributes] = false
result = nil
precondition(PlayKeychain.copyMatching(query, result: &result) == errSecSuccess)
precondition((result!.takeRetainedValue() as? [Data])?.count == 3)
query[kSecMatchLimit] = kSecMatchLimitOne
result = nil
precondition(PlayKeychain.copyMatching(query, result: &result) == errSecSuccess)
precondition(result!.takeRetainedValue() is Data)
print("PASS: numeric limits and all-match queries preserve requested keychain data and result shapes")
SWIFT
swiftc -module-cache-path "$test_dir/cache" "$test_dir/Constants.swift" "$test_dir/Support.swift" \
    "$repo_root/PlayTools/MysticRunes/PlayedAppleDB.swift" \
    "$repo_root/PlayTools/MysticRunes/PlayedApple.swift" "$test_dir/main.swift" -o "$test_dir/check"
"$test_dir/check"
