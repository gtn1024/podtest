package podtest_mysql

import std.core.{Duration, sleep}
import std.collection.ArrayList
import std.convert.Parsable
import std.time.DateTime
import podtest_core.*

public class MysqlContainer <: RdbInitSqlContainer<MysqlContainer> {
    private let _image: String
    private let _username: String
    private let _password: String
    private let _database: String
    private let _startupTimeout: Duration
    private let container: GenericContainer
    private let initSqls: ArrayList<String>
    private var initSqlExecuted: Bool = false

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
        this.initSqls = ArrayList<String>()

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

    public func withInitSql(sql: String): This {
        if (container.isStarted) {
            throw PodTestException(PodTestError.ConfigError("init SQL must be configured before container start"))
        }
        if (sql.trimAscii().isEmpty()) {
            throw PodTestException(PodTestError.ConfigError("init SQL cannot be empty"))
        }
        initSqls.add(sql)
        return this
    }

    public func start(): Unit {
        if (container.isStarted) {
            return
        }
        container.start()
        try {
            runInitSqls()
        } catch (e: PodTestException) {
            container.stop()
            throw e
        }
    }

    public func stop(): Unit {
        container.stop()
        initSqlExecuted = false
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
        stop()
    }

    private func runInitSqls(): Unit {
        if (initSqlExecuted) {
            return
        }
        if (initSqls.size == 0) {
            initSqlExecuted = true
            return
        }

        waitUntilSqlReady()

        for (sql in initSqls) {
            let result = execSql(sql)
            if (!result.success) {
                throw PodTestException(PodTestError.InitSqlFailed(initSqlFailureMessage("MySQL", result)))
            }
        }

        initSqlExecuted = true
    }

    private func waitUntilSqlReady(): Unit {
        let start = DateTime.now()
        var detail = "no output"
        while (DateTime.now() - start < _startupTimeout) {
            let result = execSql("SELECT 1;")
            if (result.success) {
                return
            }
            detail = execSqlOutput(result)
            sleep(Duration.second)
        }

        throw PodTestException(
            PodTestError.WaitTimeout("MySQL init SQL connection not ready after ${_startupTimeout}: ${detail}"))
    }

    private func execSql(sql: String): ExecResult {
        // 强制走 TCP 而非默认的 Unix socket：rootless podman 下 mysqld.sock 路径不稳定，
        // mysql 客户端默认连 /var/run/mysqld/mysqld.sock 会报 ERROR 2002。
        // 容器内回环 127.0.0.1 直连容器监听的 3306，绕开宿主端口映射与 socket 文件差异。
        // root 密码即 MYSQL_ROOT_PASSWORD，root 是可靠的 init 账户。
        container.exec(
            [
                "mysql",
                "--protocol=TCP",
                "-h127.0.0.1",
                "-P3306",
                "-uroot",
                "-p${_password}",
                _database,
                "-e",
                sql
            ]
        )
    }

    private func initSqlFailureMessage(databaseName: String, result: ExecResult): String {
        return "${databaseName} init SQL failed with exit code ${result.exitCode}: ${execSqlOutput(result)}"
    }

    private func execSqlOutput(result: ExecResult): String {
        var detail = (result.stdout + result.stderr).trimAscii()
        if (detail.isEmpty()) {
            detail = "no output"
        }
        return detail
    }
}
