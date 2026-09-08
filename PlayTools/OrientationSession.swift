//
//  OrientationSession.swift
//  PlayTools
//
//  Tracks live interface orientation and (when enabled) resizes the Mac window
//  so portrait/landscape switches behave like iPad Stage Manager.
//

import Foundation
import UIKit

@objc public final class OrientationSession: NSObject {
    @objc public static let shared = OrientationSession()

    private(set) var interfaceOrientation: UIInterfaceOrientation = .unknown
    private var baseWidth: CGFloat = 0
    private var baseHeight: CGFloat = 0
    private var lastPortraitLayout: Bool?
    private var pendingResizeAfterFullscreen = false
    private var observersInstalled = false

    /// UIDeviceOrientation raw value for `hook_orientation` when follow mode is on.
    @objc public var deviceOrientationRawValue: Int {
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

        baseWidth = mainScreenWidth
        baseHeight = mainScreenHeight
        lastPortraitLayout = baseHeight > baseWidth

        installObserversIfNeeded()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.syncFromWindowScene(resize: true)
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
        guard PlaySettings.shared.followInGameOrientation else { return point }
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
            self?.syncFromWindowScene(resize: true)
        }

        NotificationCenter.default.addObserver(
            forName: UIWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncFromWindowScene(resize: false)
            self?.restorePendingResizeIfNeeded()
        }

        // Poll lightly: some games change geometry without posting the status-bar notification.
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.syncFromWindowScene(resize: true)
            self?.restorePendingResizeIfNeeded()
        }
    }

    private func apply(orientation: UIInterfaceOrientation, resize: Bool) {
        let nowPortrait = orientation.isPortraitLike
        let orientationChanged = interfaceOrientation != orientation
        let layoutChanged = lastPortraitLayout.map { $0 != nowPortrait } ?? true

        interfaceOrientation = orientation

        guard resize, layoutChanged || (orientationChanged && lastPortraitLayout == nil) else { return }

        updateScreenDimensions(portrait: nowPortrait)

        if PlayScreen.shared.fullscreen {
            pendingResizeAfterFullscreen = true
            lastPortraitLayout = nowPortrait
            return
        }

        resizeWindow(portrait: nowPortrait)
        lastPortraitLayout = nowPortrait
        pendingResizeAfterFullscreen = false
    }

    private func updateScreenDimensions(portrait: Bool) {
        let landscapeW = max(baseWidth, baseHeight)
        let landscapeH = min(baseWidth, baseHeight)
        if portrait {
            mainScreenWidth = landscapeH
            mainScreenHeight = landscapeW
        } else {
            mainScreenWidth = landscapeW
            mainScreenHeight = landscapeH
        }
        PlaySettings.shared.windowSizeWidth = mainScreenWidth
        PlaySettings.shared.windowSizeHeight = mainScreenHeight
    }

    private func resizeWindow(portrait: Bool) {
        let landscapeW = max(baseWidth, baseHeight)
        let landscapeH = min(baseWidth, baseHeight)
        let target = portrait
            ? CGSize(width: landscapeH, height: landscapeW)
            : CGSize(width: landscapeW, height: landscapeH)
        AKInterface.shared?.setWindowContentSize(target)
    }

    private func restorePendingResizeIfNeeded() {
        guard pendingResizeAfterFullscreen, !PlayScreen.shared.fullscreen else { return }
        guard let portrait = lastPortraitLayout else { return }
        resizeWindow(portrait: portrait)
        pendingResizeAfterFullscreen = false
    }
}

private extension UIInterfaceOrientation {
    var isPortraitLike: Bool {
        self == .portrait || self == .portraitUpsideDown
    }
}
