package podtest_core

import std.core.{Duration, sleep}
import std.collection.ArrayList
import std.convert.Parsable
import std.time.DateTime

public interface InitCommandContainer <: PresetContainer {
    prop host: String
    prop port: String
    prop portNum: Int64

    func withInitCommand(cmd: String): InitCommandContainer
}

public abstract class AbstractInitCommandContainer <: InitCommandContainer {
    protected let _port: String
    protected let _startupTimeout: Duration
    protected let container: GenericContainer
    protected let initCommands: ArrayList<String>
    protected var initCommandsExecuted: Bool = false

    protected init(
        image: String,
        port: String,
        startupTimeout: Duration,
        exposedPorts: Array<String>,
        envEntries: Array<(String, String)>,
        waitLogPattern: String,
        extraArgs: Array<String>
    ) {
        this._port = port
        this._startupTimeout = startupTimeout
        this.initCommands = ArrayList<String>()

        let waitStrategies = ArrayList<WaitStrategy>()
        waitStrategies.add(TcpWait(port: port, timeout: Duration.second * 5))
        waitStrategies.add(LogWait(pattern: waitLogPattern, timeout: startupTimeout))

        let gc = GenericContainer(image).exposedPorts(exposedPorts)
        for ((k, v) in envEntries) {
            gc.env(k, v)
        }
        if (extraArgs.size > 0) {
            gc.extraArgs(extraArgs)
        }
        gc.withWaitStrategy(CompositeWait(strategies: waitStrategies))
            .withStartupTimeout(startupTimeout)
        this.container = gc
    }

    // None 表示该镜像无可用 exec 探活，仅依赖 waitStrategy。
    protected func readinessCommand(): ?Array<String>

    protected func commandCli(cmd: String): Array<String>

    protected func brandName(): String

    protected open func isReady(result: ExecResult): Bool {
        result.success
    }

    public func withInitCommand(cmd: String): AbstractInitCommandContainer {
        if (container.isStarted) {
            throw PodTestException(PodTestError.ConfigError("init command must be configured before container start"))
        }
        if (cmd.trimAscii().isEmpty()) {
            throw PodTestException(PodTestError.ConfigError("init command cannot be empty"))
        }
        initCommands.add(cmd)
        return this
    }

    public func start(): Unit {
        if (container.isStarted) {
            return
        }
        container.start()
        try {
            runInitCommands()
        } catch (e: PodTestException) {
            container.stop()
            throw e
        }
    }

    public func stop(): Unit {
        container.stop()
        initCommandsExecuted = false
    }

    public prop host: String {
        get() { "localhost" }
    }

    public prop port: String {
        get() { container.mappedPort(_port) }
    }

    public prop portNum: Int64 {
        get() { Int64.parse(container.mappedPort(_port)) }
    }

    public prop isStarted: Bool {
        get() { container.isStarted }
    }

    public func exec(command: Array<String>): ExecResult {
        container.exec(command)
    }

    public override func isClosed(): Bool {
        !container.isStarted
    }

    public override func close(): Unit {
        stop()
    }

    protected func runInitCommands(): Unit {
        if (initCommandsExecuted) {
            return
        }
        if (initCommands.size == 0) {
            initCommandsExecuted = true
            return
        }

        waitUntilReady()

        for (cmd in initCommands) {
            let result = container.exec(commandCli(cmd))
            if (!result.success) {
                throw PodTestException(PodTestError.InitCommandFailed(initCommandFailureMessage(result)))
            }
        }

        initCommandsExecuted = true
    }

    protected func waitUntilReady(): Unit {
        if (let Some(cmd) <- readinessCommand()) {
            let start = DateTime.now()
            var detail = "no output"
            while (DateTime.now() - start < _startupTimeout) {
                let result = container.exec(cmd)
                if (isReady(result)) {
                    return
                }
                detail = execOutput(result)
                sleep(Duration.second)
            }
            throw PodTestException(
                PodTestError.WaitTimeout("${brandName()} not ready after ${_startupTimeout}: ${detail}"))
        }
    }

    protected func initCommandFailureMessage(result: ExecResult): String {
        "${brandName()} init command failed with exit code ${result.exitCode}: ${execOutput(result)}"
    }

    protected func execOutput(result: ExecResult): String {
        var detail = (result.stdout + result.stderr).trimAscii()
        if (detail.isEmpty()) {
            detail = "no output"
        }
        detail
    }

    // SET k v → ["SET", "k", "v"]。不处理引号嵌套。
    protected static func tokenize(cmd: String): Array<String> {
        let tokens = ArrayList<String>()
        var current = StringBuilder()
        for (c in cmd.toRuneArray()) {
            if (c == r' ' || c == r'\t' || c == r'\n' || c == r'\r') {
                if (current.size > 0) {
                    tokens.add(current.toString())
                    current = StringBuilder()
                }
            } else {
                current.append(c)
            }
        }
        if (current.size > 0) {
            tokens.add(current.toString())
        }
        tokens.toArray()
    }
}
