package podtest_mysql

import std.core.Duration
import podtest_core.*

public class MysqlContainer <: AbstractRdbContainer<MysqlContainer> & RdbInitSqlContainer<MysqlContainer> {
    public init(
        image!: String = "docker.io/library/mysql:9.7",
        username!: String = "test",
        password!: String = "test",
        database!: String = "test",
        startupTimeout!: Duration = Duration.second * 60
    ) {
        super(
            image,
            username,
            password,
            database,
            "3306",
            startupTimeout,
            [
                ("MYSQL_ROOT_PASSWORD", password),
                ("MYSQL_USER", username),
                ("MYSQL_PASSWORD", password),
                ("MYSQL_DATABASE", database)
            ],
            "ready for connections"
        )
    }

    public func withInitSql(sql: String): MysqlContainer {
        if (container.isStarted) {
            throw PodTestException(PodTestError.ConfigError("init SQL must be configured before container start"))
        }
        if (sql.trimAscii().isEmpty()) {
            throw PodTestException(PodTestError.ConfigError("init SQL cannot be empty"))
        }
        initSqls.add(sql)
        return this
    }

    public func sqlClientCommand(sql: String): Array<String> {
        // 强制走 TCP 而非默认的 Unix socket：rootless podman 下 mysqld.sock 路径不稳定，
        // 容器内回环 127.0.0.1 直连绕开宿主端口映射与 socket 文件差异。
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
    }

    public func connectionScheme(): String {
        "mysql"
    }

    public func databaseBrandName(): String {
        "MySQL"
    }
}
