package podtest_mongodb

import std.core.Duration
import podtest_core.*

public class MongodbContainer <: AbstractInitCommandContainer {
    private let _username: String
    private let _password: String

    public init(
        image!: String = "docker.io/library/mongo:8",
        username!: String = "test",
        password!: String = "test",
        startupTimeout!: Duration = Duration.second * 60
    ) {
        super(
            image,
            "27017",
            startupTimeout,
            ["27017"],
            [
                ("MONGO_INITDB_ROOT_USERNAME", username),
                ("MONGO_INITDB_ROOT_PASSWORD", password)
            ],
            "mongod startup complete",
            []
        )
        this._username = username
        this._password = password
    }

    protected override func readinessCommand(): ?Array<String> {
        Some([
            "mongosh",
            containerUri(),
            "--quiet",
            "--eval",
            "db.adminCommand({ping:1}).ok"
        ])
    }

    // --eval 接收整段 JS，不分词（与 redis-cli 的 argv 模式相反）。
    protected override func commandCli(cmd: String): Array<String> {
        [
            "mongosh",
            containerUri(),
            "--quiet",
            "--eval",
            cmd
        ]
    }

    protected override func brandName(): String {
        "MongoDB"
    }

    protected override func isReady(result: ExecResult): Bool {
        result.success && result.stdout.trimAscii() == "1"
    }

    public prop username: String {
        get() { _username }
    }

    public prop password: String {
        get() { _password }
    }

    // root 用户建在 admin 库；连业务库需追加 ?authSource=admin（见 README）。
    public func connectionString(): String {
        "mongodb://${_username}:${_password}@${host}:${port}/admin"
    }

    private func containerUri(): String {
        "mongodb://${_username}:${_password}@127.0.0.1:27017/admin"
    }
}
