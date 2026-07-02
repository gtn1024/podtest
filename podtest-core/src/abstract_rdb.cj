package podtest_core

import std.core.{Duration, sleep}
import std.collection.ArrayList
import std.convert.Parsable
import std.time.DateTime

public abstract class AbstractRdbContainer<T> <: RdbContainer {
    protected let _image: String
    protected let _username: String
    protected let _password: String
    protected let _database: String
    protected let _portName: String
    protected let _startupTimeout: Duration
    protected let container: GenericContainer
    protected let initSqls: ArrayList<String>
    protected var initSqlExecuted: Bool = false

    protected init(
        image: String,
        username: String,
        password: String,
        database: String,
        portName: String,
        startupTimeout: Duration,
        envEntries: Array<(String, String)>,
        logWaitPattern: String
    ) {
        this._image = image
        this._username = username
        this._password = password
        this._database = database
        this._portName = portName
        this._startupTimeout = startupTimeout
        this.initSqls = ArrayList<String>()

        let waitStrategies = ArrayList<WaitStrategy>()
        waitStrategies.add(TcpWait(port: portName, timeout: Duration.second * 5))
        waitStrategies.add(LogWait(pattern: logWaitPattern, timeout: startupTimeout))

        let gc = GenericContainer(image)
            .exposedPorts([portName])
        for ((k, v) in envEntries) {
            gc.env(k, v)
        }
        gc.withWaitStrategy(CompositeWait(strategies: waitStrategies))
            .withStartupTimeout(startupTimeout)
        this.container = gc
    }

    protected func sqlClientCommand(sql: String): Array<String>

    protected func connectionScheme(): String

    protected func databaseBrandName(): String

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
            container.mappedPort(_portName)
        }
    }

    public prop portNum: Int64 {
        get() {
            let p = container.mappedPort(_portName)
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
        "${connectionScheme()}://${_username}:${_password}@${host}:${port}/${_database}"
    }

    public override func isClosed(): Bool {
        !container.isStarted
    }

    public override func close(): Unit {
        stop()
    }

    protected func runInitSqls(): Unit {
        if (initSqlExecuted) {
            return
        }
        if (initSqls.size == 0) {
            initSqlExecuted = true
            return
        }

        waitUntilSqlReady()

        for (sql in initSqls) {
            let result = container.exec(sqlClientCommand(sql))
            if (!result.success) {
                throw PodTestException(PodTestError.InitSqlFailed(initSqlFailureMessage(result)))
            }
        }

        initSqlExecuted = true
    }

    protected func waitUntilSqlReady(): Unit {
        let start = DateTime.now()
        var detail = "no output"
        while (DateTime.now() - start < _startupTimeout) {
            let result = container.exec(sqlClientCommand("SELECT 1;"))
            if (result.success) {
                return
            }
            detail = execOutput(result)
            sleep(Duration.second)
        }

        throw PodTestException(
            PodTestError.WaitTimeout("${databaseBrandName()} init SQL connection not ready after ${_startupTimeout}: ${detail}"))
    }

    protected func initSqlFailureMessage(result: ExecResult): String {
        return "${databaseBrandName()} init SQL failed with exit code ${result.exitCode}: ${execOutput(result)}"
    }

    protected func execOutput(result: ExecResult): String {
        var detail = (result.stdout + result.stderr).trimAscii()
        if (detail.isEmpty()) {
            detail = "no output"
        }
        return detail
    }
}
