package podtest_core

import std.process.{executeWithOutput, ProcessRedirect}
import std.collection.{ArrayList, HashMap}

public class ContainerClient {
    private let _config: PodTestConfig
    private let engineCmd: String

    public init(config!: PodTestConfig = PodTestConfig.global) {
        this._config = config
        let engine = config.detectEngine()
        this.engineCmd = match (engine) {
            case ContainerEngine.Docker => "docker"
            case ContainerEngine.Podman => "podman"
        }
    }

    public prop config: PodTestConfig {
        get() { this._config }
    }

    public func run(args: Array<String>): String {
        let (exitCode, stdout, stderr) = executeWithOutput(
            engineCmd,
            args,
            stdOut: ProcessRedirect.Pipe,
            stdErr: ProcessRedirect.Pipe
        )
        if (exitCode != 0) {
            let errStr = String.fromUtf8(stderr)
            throw PodTestException(PodTestError.CliError(errStr, exitCode))
        }
        return String.fromUtf8(stdout)
    }

    public func runIgnoreError(args: Array<String>): (Int64, String, String) {
        let (exitCode, stdout, stderr) = executeWithOutput(
            engineCmd,
            args,
            stdOut: ProcessRedirect.Pipe,
            stdErr: ProcessRedirect.Pipe
        )
        return (exitCode, String.fromUtf8(stdout), String.fromUtf8(stderr))
    }

    public func createContainer(
        image: String,
        name!: String = "",
        exposedPorts!: Array<String> = [],
        env!: HashMap<String, String> = HashMap<String, String>(),
        volumes!: Array<String> = [],
        network!: String = "",
        extraArgs!: Array<String> = []
    ): String {
        let args = ArrayList<String>()
        args.add("create")

        if (!name.isEmpty()) {
            args.add("--name")
            args.add(name)
        }

        args.add("--label")
        args.add("podtest=true")

        for (port in exposedPorts) {
            args.add("-p")
            args.add(port)
        }

        for ((key, value) in env) {
            args.add("-e")
            args.add("${key}=${value}")
        }

        for (vol in volumes) {
            args.add("-v")
            args.add(vol)
        }

        if (!network.isEmpty()) {
            args.add("--network")
            args.add(network)
        }

        args.add(image)

        for (a in extraArgs) {
            args.add(a)
        }

        let output = run(args.toArray())
        return output.trimAscii()
    }

    public func startContainer(containerId: String): Unit {
        run(["start", containerId])
    }

    public func stopContainer(containerId: String, timeout!: Int64 = 10): Unit {
        let (_, _, _) = runIgnoreError(["stop", "-t", "${timeout}", containerId])
    }

    public func removeContainer(containerId: String, force!: Bool = false): Unit {
        let args = ArrayList<String>()
        args.add("rm")
        if (force) {
            args.add("-f")
        }
        args.add(containerId)
        let (_, _, _) = runIgnoreError(args.toArray())
    }

    public func containerLogs(containerId: String): String {
        let (exitCode, stdout, stderr) = runIgnoreError(["logs", containerId])
        if (exitCode != 0) {
            throw PodTestException(PodTestError.CliError(stderr, exitCode))
        }
        return stdout + stderr
    }

    public func mappedPort(containerId: String, port: String): ?String {
        if (let Some(binding) <- portBinding(containerId, port)) {
            return Some(binding.hostPort)
        }
        return None
    }

    /// 按 containerPort（如 "80" 或 "80/tcp"）取结构化端口绑定（含 HostIp）。
    /// 当前依赖 docker 的 NetworkSettings.Ports 结构。
    public func portBinding(containerId: String, port: String): ?PortBinding {
        let info = inspectContainer(containerId)
        return info.portBinding(port)
    }

    /// 解析 `docker inspect <id>` 输出为结构化的 `ContainerInfo`。
    /// 当前只保证 docker 的 schema；解析失败抛 `PodTestError.InspectFailed`。
    public func inspectContainer(containerId: String): ContainerInfo {
        let raw = run(["inspect", containerId])
        return ContainerInfo.fromInspectJson(raw)
    }

    public func containerExists(containerId: String): Bool {
        let (exitCode, _, _) = runIgnoreError(["inspect", containerId])
        return exitCode == 0
    }

    public func pullImage(image: String): Unit {
        run(["pull", image])
    }

    public func imageExists(image: String): Bool {
        let (exitCode, _, _) = runIgnoreError(["image", "inspect", image])
        return exitCode == 0
    }

    public func isRunning(): Bool {
        let (exitCode, _, _) = runIgnoreError(["info"])
        return exitCode == 0
    }
}
