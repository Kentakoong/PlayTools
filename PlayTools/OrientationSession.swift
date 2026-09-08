//
//  OrientationSession.swift
//  PlayTools
//
//  Follows in-game orientation only from explicit rotate actions (menu /
//  Device Orientation setting). Mac Catalyst's UIWindowScene.interfaceOrientation
//  often stays landscape even when the app content is portrait, so using it as
//  an auto-follow signal forces 16:9 and can black-screen Fix Window games.
//

import Foundation
import UIKit

@objc public final class OrientationSession: NSObject {
    @objc public static let shared = OrientationSession()

    private(set) var interfaceOrientation: UIInterfaceOrientation = .landscapeLeft
    private var lastPortraitLayout: Bool?
    private var hasAppliedFollowChange = false
    private var pendingResizeAfterFullscreen = false

    /// UIDeviceOrientation raw value for `hook_orientation` when follow mode is on.
    /// Stays at unknown (0) until an explicit rotate has been applied, so
    /// Fix Window / inverse-screen setups keep working at launch.
    @objc public var deviceOrientationRawValue: Int {
        guard hasAppliedFollowChange else {
            return UIDeviceOrientation.unknown.rawValue
        }
        switch interfaceOrientation {
        case .portrait:
            return UIDeviceOrientation.portrait.rawValue
        case .portraitUpsideDown:
            return UIDeviceOrientation.portraitUpsideDown.rawValue
        case .landscapeLeft:
            return UIDeviceOrientation.landscapeRight.rawValue
        case .landscapeRight:
            return UIDeviceOrientation.landscapeLeft.rawValue
        default:
            return UIDeviceOrientation.unknown.rawValue
        }
    }

    func initialize() {
        // No scene/timer observers. Auto-following UIWindowScene breaks portrait
        // Fix Window launches (Gakuen Idolmaster / IDOLY PRIDE).
        guard PlaySettings.shared.followInGameOrientation else { return }
        lastPortraitLayout = mainScreenHeight > mainScreenWidth
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NSWindowDidExitFullScreenNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.restorePendingResizeIfNeeded()
        }
    }

    /// Called from the rotate-display menu / launch displayRotation path.
    func applyManualRotation(index: Int) {
        guard PlaySettings.shared.followInGameOrientation else { return }
        let list: [UIInterfaceOrientation] = [
            .landscapeLeft, .portrait, .landscapeRight, .portraitUpsideDown
        ]
        // displayRotation tag 4 ("Flip Fix") maps onto landscapeLeft via % 4;
        // treat it as a portrait/landscape flip of the current layout instead.
        if index == 4 {
            flipLayout()
            hasAppliedFollowChange = true
            lastPortraitLayout = !(lastPortraitLayout ?? false)
            interfaceOrientation = (lastPortraitLayout == true) ? .portrait : .landscapeLeft
            return
        }

        let orientation = list[((index % list.count) + list.count) % list.count]
        applyExplicit(orientation: orientation)
    }

    /// Map a point already converted into UIKit view space through the current interface orientation.
    func transformViewPoint(_ point: CGPoint, viewSize: CGSize) -> CGPoint {
        guard PlaySettings.shared.followInGameOrientation, hasAppliedFollowChange else { return point }
        switch interfaceOrientation {
        case .landscapeRight, .portraitUpsideDown:
            return CGPoint(x: viewSize.width - point.x, y: viewSize.height - point.y)
        default:
            return point
        }
    }

    private func applyExplicit(orientation: UIInterfaceOrientation) {
        let nowPortrait = orientation.isPortraitLike
        interfaceOrientation = orientation

        let previous = lastPortraitLayout
        lastPortraitLayout = nowPortrait

        // Only resize when portrait-ness actually changes.
        guard previous.map({ $0 != nowPortrait }) ?? true else { return }

        flipLayout()
        hasAppliedFollowChange = true

        if PlayScreen.shared.fullscreen {
            pendingResizeAfterFullscreen = true
        }
    }

    private func flipLayout() {
        // Only mutate runtime globals + the Mac window. Do not rewrite PlaySettings
        // windowSize* (those are lazy KVC targets used by Fix Window swizzles).
        swap(&mainScreenWidth, &mainScreenHeight)

        guard !PlayScreen.shared.fullscreen else { return }

        let current = AKInterface.shared?.windowFrame.size
            ?? CGSize(width: mainScreenWidth, height: mainScreenHeight)
        AKInterface.shared?.setWindowContentSize(
            CGSize(width: current.height, height: current.width)
        )
    }

    private func restorePendingResizeIfNeeded() {
        guard pendingResizeAfterFullscreen, !PlayScreen.shared.fullscreen else { return }
        AKInterface.shared?.setWindowContentSize(
            CGSize(width: mainScreenWidth, height: mainScreenHeight)
        )
        pendingResizeAfterFullscreen = false
    }
}

private extension UIInterfaceOrientation {
    var isPortraitLike: Bool {
        self == .portrait || self == .portraitUpsideDown
    }
}
