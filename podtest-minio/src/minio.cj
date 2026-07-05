package podtest_minio

import std.core.Duration
import podtest_core.*

public class MinioContainer <: AbstractInitCommandContainer {
    private let _accessKey: String
    private let _secretKey: String

    public init(
        image!: String = "docker.io/minio/minio:latest",
        accessKey!: String = "test",
        secretKey!: String = "testtest",
        startupTimeout!: Duration = Duration.second * 60
    ) {
        super(
            image,
            "9000",
            startupTimeout,
            ["9000"],
            [
                ("MINIO_ROOT_USER", accessKey),
                ("MINIO_ROOT_PASSWORD", secretKey)
            ],
            "API: http://",
            ["server", "/data"]
        )
        this._accessKey = accessKey
        this._secretKey = secretKey
    }

    protected override func readinessCommand(): ?Array<String> {
        Some(mcAliasLocal())
    }

    // mc alias 不跨 exec 持久；docker exec argv 不经 shell，故 sh -c 包一层。
    protected override func commandCli(cmd: String): Array<String> {
        let sb = StringBuilder()
        var first = true
        for (token in tokenize(cmd)) {
            if (!first) {
                sb.append(r' ')
            }
            sb.append(token)
            first = false
        }
        ["sh", "-c", "mc alias set local http://127.0.0.1:9000 ${_accessKey} ${_secretKey} && mc ${sb.toString()}"]
    }

    protected override func brandName(): String {
        "MinIO"
    }

    public prop accessKey: String {
        get() { _accessKey }
    }

    public prop secretKey: String {
        get() { _secretKey }
    }

    public func endpoint(): String {
        "http://${host}:${port}"
    }

    public func connectionString(): String {
        "s3://${_accessKey}:${_secretKey}@${host}:${port}"
    }

    private func mcAliasLocal(): Array<String> {
        [
            "mc",
            "alias",
            "set",
            "local",
            "http://127.0.0.1:9000",
            _accessKey,
            _secretKey
        ]
    }
}
