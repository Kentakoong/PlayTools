//
//  Plugin.swift
//  PlayTools
//
//  Created by Isaac Marovitz on 13/09/2022.
//

import Foundation
import Darwin

// Foundation home-directory APIs honor CFFIXED_USER_HOME inside a sandbox.
// Settings belong to the login user's PlayCover container, not the game's container.
func playCoverHostHomeDirectoryPath() -> String {
    var buffer = [CChar](repeating: 0, count: 16_384)
    while true {
        var entry = passwd()
        var result: UnsafeMutablePointer<passwd>?
        let status = getpwuid_r(getuid(), &entry, &buffer, buffer.count, &result)
        if status == 0, result != nil, let directory = entry.pw_dir {
            return String(cString: directory)
        }
        if status == ERANGE {
            buffer = [CChar](repeating: 0, count: buffer.count * 2)
            continue
        }
        NSLog("[PlayTools] Cannot resolve login user's home directory (status %d)", status)
        return NSHomeDirectory()
    }
}

func playCoverPreferredDisplayRotation(infoDictionary: [String: Any]) -> Int {
    let orientations = (infoDictionary["UISupportedInterfaceOrientations~ipad"] as? [String])
        ?? (infoDictionary["UISupportedInterfaceOrientations"] as? [String])
        ?? []
    switch orientations.first {
    case "UIInterfaceOrientationPortrait": return 1
    case "UIInterfaceOrientationLandscapeRight": return 2
    case "UIInterfaceOrientationPortraitUpsideDown": return 3
    default: return 0
    }
}

func playCoverNeedsLaunchCompatibilityMigration(version: String) -> Bool {
    version.compare("3.1.0", options: .numeric) == .orderedAscending
}

@objc(Plugin)
public protocol Plugin: NSObjectProtocol {
    init()

    var screenCount: Int { get }
    var mousePoint: CGPoint { get }
    var windowFrame: CGRect { get }
    var mainScreenFrame: CGRect { get }
    var isMainScreenEqualToFirst: Bool { get }
    var isFullscreen: Bool { get }
    var cmdPressed: Bool { get }

    func hideCursor()
    func hideCursorMove()
    func warpCursor()
    func unhideCursor()
    func terminateApplication()
    func setupKeyboard(keyboard: @escaping (UInt16, Bool, Bool, Bool) -> Bool,
                       swapMode: @escaping () -> Bool)
    func setupMouseMoved(_ mouseMoved: @escaping (CGFloat, CGFloat) -> Bool)
    func setupMouseButton(left: Bool, right: Bool, _ consumed: @escaping (Int, Bool) -> Bool)
    func setupScrollWheel(_ onMoved: @escaping (CGFloat, CGFloat) -> Bool)
    func urlForApplicationWithBundleIdentifier(_ value: String) -> URL?
    func setMenuBarVisible(_ value: Bool)
    func setWindowContentSize(_ size: CGSize)
}
