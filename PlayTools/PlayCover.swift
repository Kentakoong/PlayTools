//
//  PlayCover.swift
//  PlayTools
//

import Foundation
import UIKit

public class PlayCover: NSObject {

    static let shared = PlayCover()
    var menuController: MenuController?
    private var launchRotationObserver: NSObjectProtocol?
    private var launchRotationScheduled = false

    @objc static public func launch() {
        quitWhenClose()
        AKInterface.initialize()
        UserPluginLoader.initialize()
        PlayScreen.shared.initialize()
        PlayInput.shared.initialize()
        DiscordIPC.shared.initialize()

        if PlaySettings.shared.rootWorkDir {
            // Change the working directory to / just like iOS
            FileManager.default.changeCurrentDirectoryPath("/")
        }

        if PlaySettings.shared.effectiveDisplayRotation != 0 {
            shared.launchRotationObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
            ) { _ in
                shared.scheduleLaunchRotation()
            }
        }
    }

    private func scheduleLaunchRotation() {
        guard !launchRotationScheduled else { return }
        launchRotationScheduled = true
        if let observer = launchRotationObserver {
            NotificationCenter.default.removeObserver(observer)
            launchRotationObserver = nil
        }
        // Start the delay after activation, not in the dylib constructor: Unity
        // can block the main thread during launch and overwrite an earlier rotation.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let command = UIKeyCommand(
                title: "Keep Rotation Command", image: nil,
                action: #selector(UIApplication.rotateView(_:)), input: "", modifierFlags: [],
                propertyList: ["rotationIndex": PlaySettings.shared.effectiveDisplayRotation]
            )
            UIApplication.shared.rotateView(command)
        }
    }

    @objc static public func initMenu(menu: NSObject) {
        guard let menuBuilder = menu as? UIMenuBuilder else { return }
        shared.menuController = MenuController(with: menuBuilder)
    }

    static public func quitWhenClose() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name(rawValue: "NSWindowWillCloseNotification"),
            object: nil,
            queue: OperationQueue.main
        ) { notif in
            if PlayScreen.shared.nsWindow?.isEqual(notif.object) ?? false {
                // Step 1: Resign active
                for scene in UIApplication.shared.connectedScenes {
                    scene.delegate?.sceneWillResignActive?(scene)
                    NotificationCenter.default.post(name: UIScene.willDeactivateNotification,
                                                    object: scene)
                }
                UIApplication.shared.delegate?.applicationWillResignActive?(UIApplication.shared)
                NotificationCenter.default.post(name: UIApplication.willResignActiveNotification,
                                                object: UIApplication.shared)

                // Step 2: Enter background
                for scene in UIApplication.shared.connectedScenes {
                    scene.delegate?.sceneDidEnterBackground?(scene)
                    NotificationCenter.default.post(name: UIScene.didEnterBackgroundNotification,
                                                    object: scene)
                }
                UIApplication.shared.delegate?.applicationDidEnterBackground?(UIApplication.shared)
                NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification,
                                                object: UIApplication.shared)

                // Step 2.5: End UIBackgroundTask
                // There is an expiration handler, but idk how to invoke it. Skip for now.

                // Step 3: Terminate
                for scene in UIApplication.shared.connectedScenes {
                    scene.delegate?.sceneDidDisconnect?(scene)
                    NotificationCenter.default.post(name: UIScene.didDisconnectNotification,
                                                    object: scene)
                }
                UIApplication.shared.delegate?.applicationWillTerminate?(UIApplication.shared)
                // Some apps will freeze or crash when click close button if we send willTerminateNotification.
                // The developer documentation says this is a "may be called method", so it can be safely skipped.
                // https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1623111-applicationwillterminate
                // swiftlint:disable:previous line_length
//                NotificationCenter.default.post(name: UIApplication.willTerminateNotification,
//                                                object: UIApplication.shared)
                DispatchQueue.main.async(execute: AKInterface.shared!.terminateApplication)

                // Step 3.5: End BGTask
                // BGTask typically runs in another process and is tricky to terminate.
                // It may run into infinite loops, end up silently heating the device up.
                // This actually happens for ToF. Hope future developers can solve this.
            }
        }
    }

    static func delay(_ delay: Double, closure: @escaping () -> Void) {
        let when = DispatchTime.now() + delay
        DispatchQueue.main.asyncAfter(deadline: when, execute: closure)
    }
}
