package podtest_core

import std.process.{executeWithOutput, ProcessRedirect}
import std.core.Duration
import std.deriving.*
import std.env.getVariable

@Derive[Equatable]
public enum ContainerEngine {
    | Docker
    | Podman
}

@Derive[Equatable]
public enum ImagePullPolicy {
    | Always
    | Missing
    | Never
}

public class PodTestConfig {
    public var engine: ?ContainerEngine = None
    public var dockerSocketPath: String = "/var/run/docker.sock"
    public var podmanSocketPath: String = "/run/podman/podman.sock"
    public var defaultPullPolicy: ImagePullPolicy = ImagePullPolicy.Missing
    public var defaultWaitTimeout: Duration = Duration.second * 120
    public var defaultWaitInterval: Duration = Duration.second * 1
    public var defaultStartupTimeout: Duration = Duration.second * 60
    public var reuseContainer: Bool = false
    public var label: String = "podtest"
    public var removeOnExit: Bool = true
    public var host: String = "localhost"

    public init() {}

    public static let global = PodTestConfig()

    public func detectEngine(): ContainerEngine {
        if (let Some(e) <- this.engine) {
            return e
        }
        if (let Some(envEngine) <- getVariable("PODTEST_ENGINE")) {
            let detected = PodTestConfig.parseEngine(envEngine)
            this.engine = detected
            return detected
        }
        let detected = PodTestConfig.detectEngineFromSystem()
        this.engine = detected
        return detected
    }

    public static func parseEngine(engine: String): ContainerEngine {
        let normalized = engine.trimAscii().toAsciiLower()
        match (normalized) {
            case "docker" => return ContainerEngine.Docker
            case "podman" => return ContainerEngine.Podman
            case _ => throw PodTestException(PodTestError.ConfigError(
                "PODTEST_ENGINE must be 'docker' or 'podman', got '${engine}'"
            ))
        }
    }

    public static func detectEngineFromSystem(): ContainerEngine {
        try {
            let (exitCode, _, _) = executeWithOutput("docker", ["version"], stdOut: ProcessRedirect.Pipe, stdErr: ProcessRedirect.Pipe)
            if (exitCode == 0) {
                return ContainerEngine.Docker
            }
        } catch (_: Exception) {}
        try {
            let (exitCode, _, _) = executeWithOutput("podman", ["version"], stdOut: ProcessRedirect.Pipe, stdErr: ProcessRedirect.Pipe)
            if (exitCode == 0) {
                return ContainerEngine.Podman
            }
        } catch (_: Exception) {}
        throw PodTestException(PodTestError.EngineUnavailable("Neither docker nor podman found in PATH"))
    }
}
