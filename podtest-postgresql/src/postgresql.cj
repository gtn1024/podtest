package podtest_postgresql

import std.core.Duration
import podtest_core.*

/// PostgreSQL 容器，共享逻辑见 `AbstractRdbContainer`，本类只提供 PostgreSQL 特有的差异点。
public class PostgresqlContainer <: AbstractRdbContainer<PostgresqlContainer> & RdbInitSqlContainer<PostgresqlContainer> {
    public init(
        image!: String = "docker.io/library/postgres:18-alpine",
        username!: String = "test",
        password!: String = "test",
        database!: String = "test",
        startupTimeout!: Duration = Duration.second * 30
    ) {
        super(
            image,
            username,
            password,
            database,
            "5432",
            startupTimeout,
            [
                ("POSTGRES_USER", username),
                ("POSTGRES_PASSWORD", password),
                ("POSTGRES_DB", database)
            ],
            "database system is ready to accept connections"
        )
    }

    // ---- RdbInitSqlContainer：流式入队（基类负责真正的执行流程） ----
    public func withInitSql(sql: String): PostgresqlContainer {
        if (container.isStarted) {
            throw PodTestException(PodTestError.ConfigError("init SQL must be configured before container start"))
        }
        if (sql.trimAscii().isEmpty()) {
            throw PodTestException(PodTestError.ConfigError("init SQL cannot be empty"))
        }
        initSqls.add(sql)
        return this
    }

    // ---- AbstractRdbContainer 差异点 ----

    public func sqlClientCommand(sql: String): Array<String> {
        [
            "psql",
            "-v",
            "ON_ERROR_STOP=1",
            "-U",
            _username,
            "-d",
            _database,
            "-c",
            sql
        ]
    }

    public func connectionScheme(): String {
        "postgresql"
    }

    public func databaseBrandName(): String {
        "PostgreSQL"
    }
}
