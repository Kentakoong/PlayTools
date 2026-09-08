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
        if let currentSize = AKInterface.shared?.windowFrame.size {
            AKInterface.shared?.setWindowContentSize(
                CGSize(width: currentSize.height, height: currentSize.width)
            )
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
