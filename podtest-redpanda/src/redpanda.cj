package podtest_redpanda

import std.collection.ArrayList
import std.core.Duration
import podtest_core.*

public class RedpandaContainer <: AbstractInitCommandContainer {
    public init(
        image!: String = "docker.io/redpandadata/redpanda:latest",
        startupTimeout!: Duration = Duration.second * 60
    ) {
        super(
            image,
            "9092",
            startupTimeout,
            ["9092"],
            [],
            "Successfully started Redpanda",
            startupArgs()
        )
    }

    // 单节点 KRaft 模式，--overprovisioned/--smp 1/--memory 1G 是容器化测试的官方轻量参数。
    private static func startupArgs(): Array<String> {
        [
            "start",
            "--overprovisioned",
            "--smp", "1",
            "--memory", "1G",
            "--node-id", "0",
            "--kafka-addr", "internal://0.0.0.0:9092,external://0.0.0.0:19092",
            "--advertise-kafka-addr", "internal://127.0.0.1:9092,external://127.0.0.1:19092"
        ]
    }

    // rpk cluster health 的 Healthy 字段受宿主磁盘水位影响，改用 rpk topic list 探活。
    protected override func readinessCommand(): ?Array<String> {
        Some(["rpk", "topic", "list"])
    }

    protected override func commandCli(cmd: String): Array<String> {
        let args = ArrayList<String>()
        args.add("rpk")
        for (token in tokenize(cmd)) {
            args.add(token)
        }
        args.toArray()
    }

    protected override func brandName(): String {
        "Redpanda"
    }

    public func bootstrapServers(): String {
        "${host}:${port}"
    }

    public func connectionString(): String {
        "redpanda://${host}:${port}"
    }
}
