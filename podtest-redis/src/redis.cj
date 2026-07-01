package podtest_redis

import std.core.{Duration, sleep}
import std.collection.ArrayList
import std.convert.Parsable
import std.time.DateTime
import podtest_core.*

public class RedisContainer <: PresetContainer {
    private let _image: String
    private let _password: ?String
    private let _database: Int64
    private let _startupTimeout: Duration
    private let container: GenericContainer
    private let initCommands: ArrayList<String>
    private var initCommandsExecuted: Bool = false

    public init(
        image!: String = "docker.io/library/redis:8-alpine",
        password!: ?String = None,
        database!: Int64 = 0,
        startupTimeout!: Duration = Duration.second * 30
    ) {
        this._image = image
        this._password = password
        this._database = database
        this._startupTimeout = startupTimeout
        this.initCommands = ArrayList<String>()

        // Redis 官方镜像 entrypoint：若首个参数以 `-` 开头（如 `--requirepass`），
        // 自动在其前 prepend `redis-server`，故 extraArgs 写法等价于 `redis-server --requirepass <pw>`。
        let extra: Array<String> = match (password) {
            case Some(pwd) => ["--requirepass", pwd]
            case None => []
        }

        let waitStrategies = ArrayList<WaitStrategy>()
        waitStrategies.add(TcpWait(port: "6379", timeout: Duration.second * 5))
        waitStrategies.add(LogWait(
            pattern: "Ready to accept connections",
            timeout: Duration.second * 30
        ))

        this.container = GenericContainer(image)
            .exposedPorts(["6379"])
            .extraArgs(extra)
            .withWaitStrategy(CompositeWait(strategies: waitStrategies))
            .withStartupTimeout(startupTimeout)
    }

    public func withInitCommand(cmd: String): This {
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
        get() {
            "localhost"
        }
    }

    public prop port: String {
        get() {
            container.mappedPort("6379")
        }
    }

    public prop portNum: Int64 {
        get() {
            let p = container.mappedPort("6379")
            Int64.parse(p)
        }
    }

    public prop password: ?String {
        get() {
            _password
        }
    }

    public prop database: Int64 {
        get() {
            _database
        }
    }

    public prop isStarted: Bool {
        get() {
            container.isStarted
        }
    }

    /// 在已启动的容器内执行任意命令，透传 ExecResult。
    public func exec(command: Array<String>): ExecResult {
        container.exec(command)
    }

    /// 返回 go-redis / node-redis 通用格式的连接串。
    /// 无密码：`redis://host:port/db`
    /// 有密码：`redis://:pwd@host:port/db`
    public func connectionString(): String {
        match (_password) {
            case Some(pwd) => "redis://:${pwd}@${host}:${port}/${_database}"
            case None => "redis://${host}:${port}/${_database}"
        }
    }

    public override func isClosed(): Bool {
        !container.isStarted
    }

    public override func close(): Unit {
        stop()
    }

    private func runInitCommands(): Unit {
        if (initCommandsExecuted) {
            return
        }
        if (initCommands.size == 0) {
            initCommandsExecuted = true
            return
        }

        waitUntilRedisReady()

        for (cmd in initCommands) {
            let result = execRedisCli(cmd)
            if (!result.success) {
                throw PodTestException(PodTestError.InitCommandFailed(initCommandFailureMessage(result)))
            }
        }

        initCommandsExecuted = true
    }

    private func waitUntilRedisReady(): Unit {
        let start = DateTime.now()
        var detail = "no output"
        while (DateTime.now() - start < _startupTimeout) {
            let result = execRedisCli("PING")
            if (result.success && result.stdout.trimAscii() == "PONG") {
                return
            }
            detail = execOutput(result)
            sleep(Duration.second)
        }

        throw PodTestException(
            PodTestError.WaitTimeout("Redis not ready after ${_startupTimeout}: ${detail}"))
    }

    private func execRedisCli(cmd: String): ExecResult {
        // 容器内回环直连，绕开宿主端口映射差异（对齐 mysql 实现的取舍）。
        // -e: 命令在服务器侧失败时让 redis-cli 以非零码退出（默认服务器错误 exit 仍为 0）。
        let args = ArrayList<String>()
        args.add("redis-cli")
        args.add("-e")
        args.add("-h")
        args.add("127.0.0.1")
        args.add("-p")
        args.add("6379")
        if (let Some(pwd) <- _password) {
            args.add("--no-auth-warning")
            args.add("-a")
            args.add(pwd)
        }
        args.add("-n")
        args.add("${_database}")
        // 按空白分词：`SET k v` → ["SET", "k", "v"]，否则 redis-cli 会把它当成单个命令名。
        for (token in tokenize(cmd)) {
            args.add(token)
        }
        return container.exec(args.toArray())
    }

    /// 简单空白分词。不处理引号嵌套——Redis 命令参数通常不含空格；
    /// 含空格的值（如带空格的字符串）建议先 SET 一个键再引用，或在测试里直接 exec。
    private static func tokenize(cmd: String): Array<String> {
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
        return tokens.toArray()
    }

    private func initCommandFailureMessage(result: ExecResult): String {
        return "Redis init command failed with exit code ${result.exitCode}: ${execOutput(result)}"
    }

    private func execOutput(result: ExecResult): String {
        var detail = (result.stdout + result.stderr).trimAscii()
        if (detail.isEmpty()) {
            detail = "no output"
        }
        return detail
    }
}
