//
//  OrientationSession.swift
//  PlayTools
//
//  Tracks live interface orientation and (when enabled) resizes the Mac window
//  so portrait/landscape switches behave like iPad Stage Manager.
//
//  Important: do NOT mutate screen bounds or the NSWindow on first observation.
//  Games that need "Fix window display issues" already set up inverted bounds at
//  load; touching them at launch causes a black screen (e.g. Gakuen Idolmaster).
//

import Foundation
import UIKit

@objc public final class OrientationSession: NSObject {
    @objc public static let shared = OrientationSession()

    private(set) var interfaceOrientation: UIInterfaceOrientation = .unknown
    private var lastPortraitLayout: Bool?
    private var hasBaseline = false
    private var hasAppliedFollowChange = false
    private var pendingResizeAfterFullscreen = false
    private var observersInstalled = false

    /// UIDeviceOrientation raw value for `hook_orientation` when follow mode is on.
    /// Stays at unknown (0) until we have actually followed a portrait/landscape flip,
    /// so Fix Window / inverse-screen setups keep working at launch.
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
            // Interface landscapeLeft ↔ device landscapeRight
            return UIDeviceOrientation.landscapeRight.rawValue
        case .landscapeRight:
            return UIDeviceOrientation.landscapeLeft.rawValue
        default:
            return UIDeviceOrientation.unknown.rawValue
        }
    }

    func initialize() {
        guard PlaySettings.shared.followInGameOrientation else { return }

        installObserversIfNeeded()

        // Baseline only — never resize or rewrite mainScreen dims here.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.syncFromWindowScene(resize: false)
        }
    }

    /// Called from the rotate-display menu / launch displayRotation path.
    func applyManualRotation(index: Int) {
        guard PlaySettings.shared.followInGameOrientation else { return }
        let list: [UIInterfaceOrientation] = [
            .landscapeLeft, .portrait, .landscapeRight, .portraitUpsideDown
        ]
        let orientation = list[index % list.count]
        apply(orientation: orientation, resize: true)
    }

    func syncFromWindowScene(resize: Bool) {
        guard PlaySettings.shared.followInGameOrientation else { return }
        guard let scene = PlayScreen.shared.windowScene else { return }
        let orientation = scene.interfaceOrientation
        guard orientation != .unknown else { return }
        apply(orientation: orientation, resize: resize)
    }

    /// Map a point already converted into UIKit view space through the current interface orientation.
    func transformViewPoint(_ point: CGPoint, viewSize: CGSize) -> CGPoint {
        guard PlaySettings.shared.followInGameOrientation, hasAppliedFollowChange else { return point }
        switch interfaceOrientation {
        case .landscapeRight, .portraitUpsideDown:
            // 180° relative to landscapeLeft / portrait
            return CGPoint(x: viewSize.width - point.x, y: viewSize.height - point.y)
        default:
            return point
        }
    }

    private func installObserversIfNeeded() {
        guard !observersInstalled else { return }
        observersInstalled = true

        NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncFromWindowScene(resize: true)
        }

        NotificationCenter.default.addObserver(
            forName: UIScene.didActivateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Activate is noisy at launch — baseline only.
            self?.syncFromWindowScene(resize: false)
        }

        NotificationCenter.default.addObserver(
            forName: UIWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncFromWindowScene(resize: false)
            self?.restorePendingResizeIfNeeded()
        }

        // Poll for in-game orientation flips without stomping launch setup.
        Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            self?.syncFromWindowScene(resize: true)
            self?.restorePendingResizeIfNeeded()
        }
    }

    private func apply(orientation: UIInterfaceOrientation, resize: Bool) {
        let nowPortrait = orientation.isPortraitLike

        if !hasBaseline {
            interfaceOrientation = orientation
            lastPortraitLayout = nowPortrait
            hasBaseline = true
            return
        }

        let layoutChanged = lastPortraitLayout.map { $0 != nowPortrait } ?? false
        interfaceOrientation = orientation

        guard resize, layoutChanged else {
            return
        }

        // Portrait ↔ landscape crossed: swap current dims / window in place.
        flipLayout()
        hasAppliedFollowChange = true
        lastPortraitLayout = nowPortrait

        if PlayScreen.shared.fullscreen {
            pendingResizeAfterFullscreen = true
            return
        }

        pendingResizeAfterFullscreen = false
    }

    private func flipLayout() {
        swap(&mainScreenWidth, &mainScreenHeight)
        PlaySettings.shared.windowSizeWidth = mainScreenWidth
        PlaySettings.shared.windowSizeHeight = mainScreenHeight

        if PlayScreen.shared.fullscreen {
            return
        }

        // Prefer swapping the live window content size so we stay consistent with
        // whatever Catalyst / Fix Window already produced at launch.
        let current = AKInterface.shared?.windowFrame.size
            ?? CGSize(width: mainScreenWidth, height: mainScreenHeight)
        AKInterface.shared?.setWindowContentSize(
            CGSize(width: current.height, height: current.width)
        )
    }

    private func restorePendingResizeIfNeeded() {
        guard pendingResizeAfterFullscreen, !PlayScreen.shared.fullscreen else { return }
        // Dims were already flipped while fullscreen; only sync the window now.
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
