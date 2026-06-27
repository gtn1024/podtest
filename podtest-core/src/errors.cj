package podtest_core

import std.deriving.*

@Derive[Equatable]
public enum PodTestError <: ToString {
    | EngineUnavailable(String)
    | ContainerStartFailed(String)
    | ContainerStopFailed(String)
    | ContainerRemoveFailed(String)
    | ContainerNotFound(String)
    | ImagePullFailed(String)
    | PortMappingFailed(String)
    | WaitTimeout(String)
    | ConfigError(String)
    | InspectFailed(String)
    | CliError(String, Int64)

    public func toString(): String {
        match (this) {
            case EngineUnavailable(msg) => "EngineUnavailable: ${msg}"
            case ContainerStartFailed(msg) => "ContainerStartFailed: ${msg}"
            case ContainerStopFailed(msg) => "ContainerStopFailed: ${msg}"
            case ContainerRemoveFailed(msg) => "ContainerRemoveFailed: ${msg}"
            case ContainerNotFound(msg) => "ContainerNotFound: ${msg}"
            case ImagePullFailed(msg) => "ImagePullFailed: ${msg}"
            case PortMappingFailed(msg) => "PortMappingFailed: ${msg}"
            case WaitTimeout(msg) => "WaitTimeout: ${msg}"
            case ConfigError(msg) => "ConfigError: ${msg}"
            case InspectFailed(msg) => "InspectFailed: ${msg}"
            case CliError(msg, code) => "CliError: ${msg} (exit code: ${code})"
        }
    }
}

public class PodTestException <: Exception {
    let _error: PodTestError
    public init(error: PodTestError) {
        super(error.toString())
        this._error = error
    }

    public prop error: PodTestError {
        get() { _error }
    }
}
