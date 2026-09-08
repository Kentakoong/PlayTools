//
//  OrientationSession.swift
//  PlayTools
//
//  Keeps the screen geometry exposed to iOS apps in sync with real UIKit
//  portrait/landscape transitions.
//

import Foundation
import UIKit

@objc public final class OrientationSession: NSObject {
    @objc public static let shared = OrientationSession()

    private(set) var interfaceOrientation: UIInterfaceOrientation = .unknown
    private var portraitLayout = false
    private var hasAppliedTransition = false
    private var orientationTimer: Timer?
    private var candidatePortraitLayout: Bool?
    private var candidateObservationCount = 0

    @objc public var deviceOrientationRawValue: Int {
        guard hasAppliedTransition else { return UIDeviceOrientation.unknown.rawValue }
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
        interfaceOrientation = orientation(for: PlaySettings.shared.effectiveDisplayRotation)
        portraitLayout = interfaceOrientation.isPortraitLike
        orientationTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.observeGameOrientation()
        }
    }

    func applyManualRotation(index: Int) {
        candidatePortraitLayout = nil
        candidateObservationCount = 0
        apply(orientation: orientation(for: index))
    }

    func transformViewPoint(_ point: CGPoint, viewSize: CGSize) -> CGPoint {
        guard hasAppliedTransition else { return point }
        switch interfaceOrientation {
        case .landscapeRight, .portraitUpsideDown:
            return CGPoint(x: viewSize.width - point.x, y: viewSize.height - point.y)
        default:
            return point
        }
    }

    private func apply(orientation: UIInterfaceOrientation) {
        let nextPortrait = orientation.isPortraitLike
        interfaceOrientation = orientation
        guard nextPortrait != portraitLayout else { return }

        swap(&mainScreenWidth, &mainScreenHeight)
        PlaySettings.shared.windowSizeWidth = mainScreenWidth
        PlaySettings.shared.windowSizeHeight = mainScreenHeight
        portraitLayout = nextPortrait
        hasAppliedTransition = true

        guard !PlayScreen.shared.fullscreen else { return }
        requestSceneResize(portrait: nextPortrait)
    }

    private func requestSceneResize(portrait: Bool) {
        guard let scene = PlayScreen.shared.windowScene,
              let interface = AKInterface.shared,
              let restrictions = scene.sizeRestrictions
        else { return }

        let currentSize = interface.windowFrame.size
        let shortSide = min(currentSize.width, currentSize.height)
        let longSide = max(currentSize.width, currentSize.height)
        let targetSize = portrait
            ? CGSize(width: shortSide, height: longSide)
            : CGSize(width: longSide, height: shortSide)
        restrictions.minimumSize = targetSize
        restrictions.maximumSize = targetSize

        // Let UIKit apply the constrained scene geometry before returning the
        // window to its normal user-resizable range.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak scene] in
            scene?.sizeRestrictions?.minimumSize = CGSize(width: 0, height: 0)
            scene?.sizeRestrictions?.maximumSize = CGSize(width: CGFloat.greatestFiniteMagnitude,
                                                           height: CGFloat.greatestFiniteMagnitude)
        }

        // Unmodified iOS-on-Mac apps can ignore sizeRestrictions. Wait until
        // UIKit's orientation/layout transaction is complete before asking
        // AppKit to update only the content size.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            AKInterface.shared?.setWindowContentSize(targetSize)
        }
    }

    private func observeGameOrientation() {
        guard let window = PlayScreen.shared.window else { return }
        let sceneOrientation = window.windowScene?.interfaceOrientation
        let mask = window.rootViewController?.supportedInterfaceOrientations ?? []
        let supportsPortrait = mask.contains(.portrait) || mask.contains(.portraitUpsideDown)
        let supportsLandscape = mask.contains(.landscapeLeft) || mask.contains(.landscapeRight)
        let requestedPortraitLayout: Bool?
        if let sceneOrientation, sceneOrientation.isPortraitLike || sceneOrientation.isLandscape {
            requestedPortraitLayout = sceneOrientation.isPortraitLike
        } else if supportsPortrait != supportsLandscape {
            requestedPortraitLayout = supportsPortrait
        } else {
            requestedPortraitLayout = nil
        }
        guard let requestedPortraitLayout else {
            candidatePortraitLayout = nil
            candidateObservationCount = 0
            return
        }

        if candidatePortraitLayout == requestedPortraitLayout {
            candidateObservationCount += 1
        } else {
            candidatePortraitLayout = requestedPortraitLayout
            candidateObservationCount = 1
        }
        guard candidateObservationCount >= 2, requestedPortraitLayout != portraitLayout else { return }

        candidateObservationCount = 0
        NSLog("[PlayTools] Game requested %@ layout", requestedPortraitLayout ? "portrait" : "landscape")
        apply(orientation: requestedPortraitLayout ? .portrait : .landscapeLeft)
    }

    private func orientation(for index: Int) -> UIInterfaceOrientation {
        let orientations: [UIInterfaceOrientation] = [
            .landscapeLeft, .portrait, .landscapeRight, .portraitUpsideDown
        ]
        let normalizedIndex = ((index % orientations.count) + orientations.count) % orientations.count
        return orientations[normalizedIndex]
    }
}

private extension UIInterfaceOrientation {
    var isPortraitLike: Bool {
        self == .portrait || self == .portraitUpsideDown
    }
}
