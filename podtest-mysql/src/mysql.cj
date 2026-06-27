package podtest_mysql

import std.core.Duration
import std.collection.ArrayList
import std.convert.Parsable
import podtest_core.*

public class MysqlContainer <: RdbContainer {
    private let _image: String
    private let _username: String
    private let _password: String
    private let _database: String
    private let _startupTimeout: Duration
    private let container: GenericContainer

    public init(
        image!: String = "docker.io/library/mysql:9.7",
        username!: String = "test",
        password!: String = "test",
        database!: String = "test",
        startupTimeout!: Duration = Duration.second * 60
    ) {
        this._image = image
        this._username = username
        this._password = password
        this._database = database
        this._startupTimeout = startupTimeout

        let waitStrategies = ArrayList<WaitStrategy>()
        waitStrategies.add(TcpWait(port: "3306", timeout: Duration.second * 5))
        waitStrategies.add(LogWait(
            pattern: "ready for connections",
            timeout: Duration.second * 60
        ))

        this.container = GenericContainer(image)
            .exposedPorts(["3306"])
            .env("MYSQL_ROOT_PASSWORD", password)
            .env("MYSQL_USER", username)
            .env("MYSQL_PASSWORD", password)
            .env("MYSQL_DATABASE", database)
            .withWaitStrategy(CompositeWait(strategies: waitStrategies))
            .withStartupTimeout(startupTimeout)
    }

    public func start(): Unit {
        container.start()
    }

    public func stop(): Unit {
        container.stop()
    }

    public prop host: String {
        get() {
            "localhost"
        }
    }

    public prop port: String {
        get() {
            container.mappedPort("3306")
        }
    }

    public prop portNum: Int64 {
        get() {
            let p = container.mappedPort("3306")
            Int64.parse(p)
        }
    }

    public prop username: String {
        get() {
            _username
        }
    }

    public prop password: String {
        get() {
            _password
        }
    }

    public prop database: String {
        get() {
            _database
        }
    }

    public prop isStarted: Bool {
        get() {
            container.isStarted
        }
    }

    public func connectionString(): String {
        "mysql://${_username}:${_password}@${host}:${port}/${_database}"
    }

    public override func isClosed(): Bool {
        !container.isStarted
    }

    public override func close(): Unit {
        container.stop()
    }
}
