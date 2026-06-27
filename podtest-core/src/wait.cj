package podtest_core

import std.net.TcpSocket
import std.core.{Duration, sleep}
import std.time.DateTime
import std.convert.Parsable
import std.collection.ArrayList

public interface WaitStrategy {
    func waitUntilReady(client: ContainerClient, containerId: String, host: String): Unit
}

public class TcpWait <: WaitStrategy {
    private let port: String
    private let timeout: Duration
    private let interval: Duration

    public init(port!: String, timeout!: Duration = Duration.second * 60, interval!: Duration = Duration.second * 1) {
        this.port = port
        this.timeout = timeout
        this.interval = interval
    }

    public func waitUntilReady(client: ContainerClient, containerId: String, host: String): Unit {
        let start = DateTime.now()
        let mapped = client.mappedPort(containerId, port)
        let portNum = match (mapped) {
            case Some(p) => p
            case None => throw PodTestException(PodTestError.PortMappingFailed(
                "Port ${port} not mapped for container ${containerId}"
            ))
        }
        let portInt = UInt16.parse(portNum)
        while (DateTime.now() - start < timeout) {
            try {
                let socket = TcpSocket(host, portInt)
                socket.connect(timeout: Duration.second * 2)
                socket.close()
                return
            } catch (_: Exception) {
                sleep(interval)
            }
        }
        throw PodTestException(PodTestError.WaitTimeout(
            "TCP port ${port} (mapped to ${portNum}) not ready after ${timeout}"
        ))
    }
}

public class LogWait <: WaitStrategy {
    private let pattern: String
    private let timeout: Duration
    private let interval: Duration

    public init(pattern!: String, timeout!: Duration = Duration.second * 60, interval!: Duration = Duration.second * 1) {
        this.pattern = pattern
        this.timeout = timeout
        this.interval = interval
    }

    public func waitUntilReady(client: ContainerClient, containerId: String, _: String): Unit {
        let start = DateTime.now()
        while (DateTime.now() - start < timeout) {
            try {
                let logs = client.containerLogs(containerId)
                if (logs.contains(pattern)) {
                    return
                }
            } catch (_: Exception) {}
            sleep(interval)
        }
        throw PodTestException(PodTestError.WaitTimeout(
            "Log pattern '${pattern}' not found after ${timeout}"
        ))
    }
}

public class CompositeWait <: WaitStrategy {
    private let strategies: ArrayList<WaitStrategy>

    public init(strategies!: ArrayList<WaitStrategy>) {
        this.strategies = strategies
    }

    public func waitUntilReady(client: ContainerClient, containerId: String, host: String): Unit {
        for (strategy in strategies) {
            strategy.waitUntilReady(client, containerId, host)
        }
    }
}
