//
//  OrientationSession.swift
//  PlayTools
//
//  Temporarily inert while we bisect the Fix Window black-screen regression.
//  Stock graphics path is restored; follow/resize logic will return once
//  App Default + Fix Window renders again on Gakuen Idolmaster.
//

import Foundation
import UIKit

@objc public final class OrientationSession: NSObject {
    @objc public static let shared = OrientationSession()

    private(set) var interfaceOrientation: UIInterfaceOrientation = .landscapeLeft

    @objc public var deviceOrientationRawValue: Int {
        UIDeviceOrientation.unknown.rawValue
    }

    func initialize() {}

    func applyManualRotation(index: Int) {
        _ = index
    }

    func transformViewPoint(_ point: CGPoint, viewSize: CGSize) -> CGPoint {
        _ = viewSize
        return point
    }
}
