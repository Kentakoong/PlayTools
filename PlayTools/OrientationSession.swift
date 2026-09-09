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
    private var candidateOrientation: UIInterfaceOrientation?
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
        updateVirtualScreenSize(portrait: portraitLayout)
        orientationTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.observeGameOrientation()
        }
    }

    func applyManualRotation(index: Int) {
        candidateOrientation = nil
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
        hasAppliedTransition = true
        guard nextPortrait != portraitLayout else { return }

        updateVirtualScreenSize(portrait: nextPortrait)
        portraitLayout = nextPortrait
    }

    func completeRotation() {
        guard !PlayScreen.shared.fullscreen else { return }
        requestSceneResize(portrait: portraitLayout)
    }

    private func updateVirtualScreenSize(portrait: Bool) {
        let shortSide = min(mainScreenWidth, mainScreenHeight)
        let longSide = max(mainScreenWidth, mainScreenHeight)
        mainScreenWidth = portrait ? shortSide : longSide
        mainScreenHeight = portrait ? longSide : shortSide
        PlaySettings.shared.windowSizeWidth = mainScreenWidth
        PlaySettings.shared.windowSizeHeight = mainScreenHeight
    }

    private func requestSceneResize(portrait: Bool) {
        guard PlayScreen.shared.windowScene != nil,
              let interface = AKInterface.shared
        else { return }

        let currentSize = interface.windowContentSize
        let shortSide = min(currentSize.width, currentSize.height)
        let longSide = max(currentSize.width, currentSize.height)
        let targetSize = portrait
            ? CGSize(width: shortSide, height: longSide)
            : CGSize(width: longSide, height: shortSide)
        guard shortSide > 0 else { return }
        interface.setWindowContentSize(targetSize)
    }

    private func observeGameOrientation() {
        guard let window = PlayScreen.shared.window else { return }
        guard let root = window.rootViewController,
              root.presentedViewController == nil,
              !root.isBeingPresented, !root.isBeingDismissed else { return }
        let sceneOrientation = window.windowScene?.interfaceOrientation ?? .unknown
        let mask = root.supportedInterfaceOrientations
        guard let rawOrientation = playCoverRequestedOrientation(
            sceneOrientation: sceneOrientation.rawValue, supportedOrientations: mask.rawValue),
              let requested = UIInterfaceOrientation(rawValue: rawOrientation) else {
            candidateOrientation = nil
            candidateObservationCount = 0
            return
        }

        if candidateOrientation == requested {
            candidateObservationCount += 1
        } else {
            candidateOrientation = requested
            candidateObservationCount = 1
        }
        guard candidateObservationCount >= 2, requested != interfaceOrientation else { return }

        candidateObservationCount = 0
        let orientations: [UIInterfaceOrientation] = [.landscapeLeft, .portrait, .landscapeRight, .portraitUpsideDown]
        guard let index = orientations.firstIndex(of: requested) else { return }
        // Updating virtual bounds alone leaves Unity waiting for UIKit.
        root.rotateView(self, deviceOrientation: index)
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
