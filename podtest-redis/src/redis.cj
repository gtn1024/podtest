package podtest_redis

import std.collection.ArrayList
import std.core.Duration
import podtest_core.*

public class RedisContainer <: AbstractInitCommandContainer {
    private let _password: ?String
    private let _database: Int64

    public init(
        image!: String = "docker.io/library/redis:8-alpine",
        password!: ?String = None,
        database!: Int64 = 0,
        startupTimeout!: Duration = Duration.second * 30
    ) {
        super(
            image,
            "6379",
            startupTimeout,
            ["6379"],
            [],
            "Ready to accept connections",
            redisExtraArgs(password)
        )
        this._password = password
        this._database = database
    }

    // 镜像 entrypoint 会在以 `-` 开头的参数前 prepend `redis-server`，
    // 故 extraArgs 写法等价于 `redis-server --requirepass <pw>`。
    private static func redisExtraArgs(password: ?String): Array<String> {
        match (password) {
            case Some(pwd) => ["--requirepass", pwd]
            case None => []
        }
    }

    protected override func readinessCommand(): ?Array<String> {
        let args = redisCliBase()
        args.add("PING")
        Some(args.toArray())
    }

    protected override func commandCli(cmd: String): Array<String> {
        let args = redisCliBase()
        for (token in tokenize(cmd)) {
            args.add(token)
        }
        args.toArray()
    }

    protected override func brandName(): String {
        "Redis"
    }

    protected override func isReady(result: ExecResult): Bool {
        result.success && result.stdout.trimAscii() == "PONG"
    }

    public prop password: ?String {
        get() { _password }
    }

    public prop database: Int64 {
        get() { _database }
    }

    // redis://host:port/db  或  redis://:pwd@host:port/db
    public func connectionString(): String {
        match (_password) {
            case Some(pwd) => "redis://:${pwd}@${host}:${port}/${_database}"
            case None => "redis://${host}:${port}/${_database}"
        }
    }

    // 容器内回环直连，绕开宿主端口映射差异（对齐 mysql 的取舍）。
    // -e：服务器侧失败时让 redis-cli 以非零码退出（默认 exit 仍为 0）。
    private func redisCliBase(): ArrayList<String> {
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
        args
    }
}
