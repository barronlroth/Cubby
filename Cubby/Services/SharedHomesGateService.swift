import Foundation
import SwiftUI

protocol SharedHomesGateServiceProtocol {
    func isEnabled() -> Bool
}

final class SharedHomesGateService: SharedHomesGateServiceProtocol {
    static let runtimeEnvironmentKey = "SHARED_HOMES_ENABLED"
    static let runtimeLaunchArgument = "SHARED_HOMES_ENABLED"
    static let localOverrideEnvironmentKey = "SHARED_HOMES_LOCAL_OVERRIDE"
    static let forceEnableLaunchArgument = "FORCE_ENABLE_SHARED_HOMES"
    static let forceDisableLaunchArgument = "FORCE_DISABLE_SHARED_HOMES"

    private let distributionEnabled: Bool
    private let runtimeEnabled: Bool
    private let localOverride: Bool?
    private let allowLocalOverride: Bool

    init(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        distributionEnabled: Bool? = nil,
        runtimeOverride: Bool? = nil,
        localOverride: Bool? = nil,
        allowLocalOverride: Bool? = nil
    ) {
        self.distributionEnabled = distributionEnabled
            ?? FeatureGate.shouldUseCoreDataSharingStack(arguments: arguments, environment: environment)
        self.runtimeEnabled = runtimeOverride
            ?? Self.resolveRuntimeFlag(arguments: arguments, environment: environment)
        self.localOverride = localOverride
            ?? Self.resolveLocalOverride(arguments: arguments, environment: environment)
        self.allowLocalOverride = allowLocalOverride
            ?? Self.isInternalBuild(environment: environment)
    }

    func isEnabled() -> Bool {
        if allowLocalOverride, let localOverride {
            return localOverride
        }

        guard distributionEnabled else {
            return false
        }

        return runtimeEnabled
    }
}

private extension SharedHomesGateService {
    static func resolveRuntimeFlag(
        arguments: [String],
        environment: [String: String]
    ) -> Bool {
        if let raw = environment[runtimeEnvironmentKey],
           let value = parseBool(raw) {
            return value
        }

        return arguments.contains(runtimeLaunchArgument)
    }

    static func resolveLocalOverride(
        arguments: [String],
        environment: [String: String]
    ) -> Bool? {
        if arguments.contains(forceEnableLaunchArgument) {
            return true
        }

        if arguments.contains(forceDisableLaunchArgument) {
            return false
        }

        if let raw = environment[localOverrideEnvironmentKey] {
            return parseBool(raw)
        }

        return nil
    }

    static func parseBool(_ rawValue: String) -> Bool? {
        switch rawValue.lowercased() {
        case "1", "true", "yes", "y", "on":
            return true
        case "0", "false", "no", "n", "off":
            return false
        default:
            return nil
        }
    }

    static func isInternalBuild(environment: [String: String]) -> Bool {
#if DEBUG
        true
#else
        environment["XCTestConfigurationFilePath"] != nil
#endif
    }
}

private struct SharedHomesGateEnvironmentKey: EnvironmentKey {
    static let defaultValue: any SharedHomesGateServiceProtocol = DisabledSharedHomesGateService()
}

private struct DisabledSharedHomesGateService: SharedHomesGateServiceProtocol {
    func isEnabled() -> Bool { false }
}

extension EnvironmentValues {
    var sharedHomesGateService: any SharedHomesGateServiceProtocol {
        get { self[SharedHomesGateEnvironmentKey.self] }
        set { self[SharedHomesGateEnvironmentKey.self] = newValue }
    }
}
