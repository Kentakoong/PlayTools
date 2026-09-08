import Foundation
import UIKit

let settings = PlaySettings.shared

func playCoverUserHomeDirectoryPath() -> String {
    playCoverHostHomeDirectoryPath()
}

func playCoverContainerBaseURL() -> URL {
    URL(fileURLWithPath: playCoverUserHomeDirectoryPath(), isDirectory: true)
        .appendingPathComponent("Library", isDirectory: true)
        .appendingPathComponent("Containers", isDirectory: true)
        .appendingPathComponent("io.playcover.PlayCover", isDirectory: true)
}

@objc public final class PlaySettings: NSObject {
    @objc public static let shared = PlaySettings()

    let bundleIdentifier = Bundle.main.infoDictionary?["CFBundleIdentifier"] as? String ?? ""
    let settingsUrl: URL
    var settingsData: AppSettingsData

    override init() {
        settingsUrl = playCoverContainerBaseURL()
            .appendingPathComponent("App Settings")
            .appendingPathComponent("\(bundleIdentifier).plist")
        do {
            let data = try Data(contentsOf: settingsUrl)
            settingsData = try PropertyListDecoder().decode(AppSettingsData.self, from: data)
            if playCoverNeedsLaunchCompatibilityMigration(version: settingsData.version) {
                if settingsData.displayRotation == 0 { settingsData.displayRotation = -1 }
                settingsData.playChain = true
                settingsData.version = "3.1.0"
            }
        } catch {
            settingsData = AppSettingsData()
            NSLog("[PlayTools] Could not load settings at %@: %@", settingsUrl.path, error.localizedDescription)
        }
    }

    lazy var discordActivity = settingsData.discordActivity

    lazy var keymapping = settingsData.keymapping

    lazy var notch = settingsData.notch

    lazy var sensitivity = settingsData.sensitivity / 100

    @objc lazy var bypass = settingsData.bypass

    // Keep as lazy @objc vars so KVC setValue:from App Default / Fix Window swizzles works.
    @objc lazy var windowSizeHeight = CGFloat(settingsData.windowHeight)

    @objc lazy var windowSizeWidth = CGFloat(settingsData.windowWidth)

    @objc lazy var inverseScreenValues = settingsData.inverseScreenValues

    @objc lazy var adaptiveDisplay = settingsData.resolution == 0 ? false : true

    @objc lazy var resizableWindow = settingsData.resolution == 6 ? true : false

    @objc lazy var deviceModel = settingsData.iosDeviceModel as NSString

    @objc lazy var oemID: NSString = {
        switch settingsData.iosDeviceModel {
        case "iPad6,7":
            return "J98aAP"
        case "iPad8,6":
            return "J320xAP"
        case "iPad13,8":
            return "J522AP"
        case "iPad14,5":
            return "A2436"
        case "iPad16,6":
            return "A2925"
        case "iPhone14,3":
            return "A2645"
        case "iPhone15,3":
            return "A2896"
        case "iPhone16,2":
            return "A2849"
        case "iPhone17,2":
            return "A3084"
        default:
            return "J320xAP"
        }
    }()

    @objc lazy var playChain = settingsData.playChain

    @objc lazy var playChainDebugging = settingsData.playChainDebugging

    @objc lazy var windowFixMethod = settingsData.windowFixMethod

    @objc lazy var customScaler = settingsData.customScaler

    @objc lazy var rootWorkDir = settingsData.rootWorkDir

    @objc lazy var noKMOnInput = settingsData.noKMOnInput

    @objc lazy var enableScrollWheel = settingsData.enableScrollWheel

    @objc lazy var hideTitleBar = settingsData.hideTitleBar

    @objc lazy var floatingWindow = settingsData.floatingWindow

    @objc lazy var displayRotation = settingsData.displayRotation

    @objc lazy var effectiveDisplayRotation: Int = {
        guard settingsData.displayRotation < 0 else { return settingsData.displayRotation }
        return playCoverPreferredDisplayRotation(infoDictionary: Bundle.main.infoDictionary ?? [:])
    }()

    // Real UIKit orientation changes should work without per-game setup.
    @objc lazy var followInGameOrientation = true

    @objc lazy var checkMicPermissionSync = settingsData.checkMicPermissionSync

    @objc lazy var limitMotionUpdateFrequency = settingsData.limitMotionUpdateFrequency

    @objc lazy var disableBuiltinMouse = settingsData.disableBuiltinMouse

    @objc lazy var blockSleepSpamming = settingsData.blockSleepSpamming

    @objc lazy var ignoreUnityKeyboardInitializationError = settingsData.ignoreUnityKeyboardInitializationError
}

struct AppSettingsData: Codable {
    var keymapping = true
    var sensitivity: Float = 50

    var disableTimeout = false
    var iosDeviceModel = "iPad13,8"
    var windowWidth = 1920
    var windowHeight = 1080
    var customScaler = 2.0
    var resolution = 2
    var aspectRatio = 1
    var displayRotation = -1
    var followInGameOrientation: Bool? = nil
    var notch = false
    var bypass = false
    var discordActivity = DiscordActivity()
    var version = "3.1.0"
    var playChain = true
    var playChainDebugging = false
    var inverseScreenValues = false
    var windowFixMethod = 0
    var rootWorkDir = true
    var noKMOnInput = false
    var enableScrollWheel = true
    var hideTitleBar = false
    var floatingWindow = false
    var checkMicPermissionSync = false
    var limitMotionUpdateFrequency = false
    var disableBuiltinMouse = false
    var resizableAspectRatioType = 0
    var resizableAspectRatioWidth = 0
    var resizableAspectRatioHeight = 0
    var blockSleepSpamming = false
    var ignoreUnityKeyboardInitializationError = false
}
