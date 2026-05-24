package podtest_core

import std.collection.{ArrayList, HashMap}
import std.core.{Duration, Resource}
import std.random.Random

public class GenericContainer <: Resource {
    private let image: String
    private var containerName: String
    private var containerId: ?String = None
    private var exposedPortsList: ArrayList<String> = ArrayList<String>()
    private var envMap: HashMap<String, String> = HashMap<String, String>()
    private var volumesList: ArrayList<String> = ArrayList<String>()
    private var networkStr: String = ""
    private var _waitStrategy: ?WaitStrategy = None
    private var _startupTimeout: Duration
    private var _pullPolicy: ?ImagePullPolicy = None
    private var extraArgsList: ArrayList<String> = ArrayList<String>()
    private var started: Bool = false

    private let client: ContainerClient
    private let imageManager: ImageManager
    private let config: PodTestConfig

    public init(image: String, config!: PodTestConfig = PodTestConfig.global) {
        this.image = image
        this.config = config
        this.client = ContainerClient(config: config)
        this.imageManager = ImageManager(client: client)
        this._startupTimeout = config.defaultStartupTimeout
        this.containerName = "podtest_${Random().nextUInt64()}"
    }

    public func exposedPorts(ports: Array<String>): GenericContainer {
        for (p in ports) {
            exposedPortsList.add(p)
        }
        return this
    }

    public func env(key: String, value: String): GenericContainer {
        envMap.add(key, value)
        return this
    }

    public func volume(source: String, dest: String): GenericContainer {
        volumesList.add("${source}:${dest}")
        return this
    }

    public func network(network: String): GenericContainer {
        this.networkStr = network
        return this
    }

    public func withWaitStrategy(strategy: WaitStrategy): GenericContainer {
        this._waitStrategy = strategy
        return this
    }

    public func withStartupTimeout(timeout: Duration): GenericContainer {
        this._startupTimeout = timeout
        return this
    }

    public func withPullPolicy(policy: ImagePullPolicy): GenericContainer {
        this._pullPolicy = policy
        return this
    }

    public func extraArgs(args: Array<String>): GenericContainer {
        for (a in args) {
            extraArgsList.add(a)
        }
        return this
    }

    public func start(): Unit {
        if (started) {
            return
        }
        imageManager.ensureImage(image, pullPolicy: _pullPolicy)

        let id = client.createContainer(
            image,
            name: containerName,
            exposedPorts: exposedPortsList.toArray(),
            env: envMap,
            volumes: volumesList.toArray(),
            network: networkStr,
            extraArgs: extraArgsList.toArray()
        )
        containerId = id

        try {
            client.startContainer(id)
        } catch (e: PodTestException) {
            client.removeContainer(id, force: true)
            throw e
        }

        if (let Some(strategy) <- _waitStrategy) {
            try {
                strategy.waitUntilReady(client, id, config.host)
            } catch (e: PodTestException) {
                client.stopContainer(id)
                client.removeContainer(id, force: true)
                containerId = None
                throw e
            }
        }

        started = true
    }

    public func stop(): Unit {
        if (!started) {
            return
        }
        if (let Some(id) <- containerId) {
            client.stopContainer(id)
            if (config.removeOnExit) {
                client.removeContainer(id, force: true)
            }
            containerId = None
            started = false
        }
    }

    public prop host: String {
        get() { config.host }
    }

    public func mappedPort(port: String): String {
        if (let Some(id) <- containerId) {
            let mapped = client.mappedPort(id, port)
            return match (mapped) {
                case Some(p) => p
                case None => throw PodTestException(PodTestError.PortMappingFailed(
                    "Port ${port} not mapped"
                ))
            }
        }
        throw PodTestException(PodTestError.ContainerNotFound("Container not started"))
    }

    public func logs(): String {
        if (let Some(id) <- containerId) {
            return client.containerLogs(id)
        }
        throw PodTestException(PodTestError.ContainerNotFound("Container not started"))
    }

    public prop isStarted: Bool {
        get() { started }
    }

    public override func isClosed(): Bool {
        !started
    }

    public override func close(): Unit {
        stop()
    }
}
