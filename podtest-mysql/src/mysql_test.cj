package podtest_mysql

import std.unittest.*
import std.unittest.testmacro.*
import podtest_core.{PodTestError, PodTestException, PresetContainer, RdbContainer, RdbInitSqlContainer}

func expectMysqlContainerContract(container: PresetContainer) {
    @Expect(container.isStarted)
}

func expectMysqlRdbContract(rdb: RdbContainer) {
    @Expect(rdb.isStarted)
    @Expect(rdb.username == "test")
    @Expect(rdb.password == "test")
    @Expect(rdb.database == "test")
    @Expect(rdb.host == "localhost")
    @Expect(rdb.portNum > 0)

    let connStr = rdb.connectionString()
    @Expect(connStr.contains("mysql://"))
    @Expect(connStr.contains(":" + rdb.port))
}

func withMysqlInitSql(rdb: RdbInitSqlContainer<MysqlContainer>): MysqlContainer {
    rdb.withInitSql("CREATE TABLE podtest_init_items (id INT PRIMARY KEY, name TEXT NOT NULL);")
}

func expectMysqlInitSqlFailure(error: PodTestError) {
    @Expect(error.toString().contains("InitSqlFailed"))
    @Expect(error.toString().contains("MySQL"))
}

func expectMysqlConfigFailure(error: PodTestError) {
    @Expect(error.toString().contains("ConfigError"))
    @Expect(error.toString().contains("init SQL cannot be empty"))
}

@Test
func testMysqlContainerDefaultImage() {
    let mysql = MysqlContainer()
    mysql.start()
    let base: PresetContainer = mysql
    expectMysqlContainerContract(base)

    let rdb: RdbContainer = mysql
    expectMysqlRdbContract(rdb)

    mysql.stop()
    @Expect(!mysql.isStarted)
}

@Test
func testMysqlContainerCustomCredentials() {
    let mysql = MysqlContainer(
        username: "myuser",
        password: "mypass",
        database: "mydb"
    )
    mysql.start()

    @Expect(mysql.username == "myuser")
    @Expect(mysql.password == "mypass")
    @Expect(mysql.database == "mydb")

    let connStr = mysql.connectionString()
    @Expect(connStr.contains("myuser"))
    @Expect(connStr.contains("mydb"))

    mysql.stop()
}

@Test
func testMysqlContainerInitSql() {
    try (mysql = withMysqlInitSql(MysqlContainer())
        .withInitSql("INSERT INTO podtest_init_items (id, name) VALUES (1, 'seed');")
        .withInitSql(
            "CREATE TABLE podtest_init_assert (id INT NOT NULL, CONSTRAINT fk_podtest_init FOREIGN KEY (id) REFERENCES podtest_init_items(id));")
        .withInitSql("INSERT INTO podtest_init_assert (id) VALUES (1);")) {
        mysql.start()
        @Expect(mysql.isStarted)
    }
}

@Test
func testMysqlContainerInitSqlFailure() {
    try (mysql = MysqlContainer().withInitSql("SELECT * FROM podtest_missing_table;")) {
        var caught: ?PodTestError = None
        try {
            mysql.start()
        } catch (e: PodTestException) {
            caught = Some(e.error)
        }

        @Expect(caught.isSome())
        expectMysqlInitSqlFailure(caught.getOrThrow())
        @Expect(!mysql.isStarted)
    }
}

@Test
func testMysqlContainerInitSqlEmpty() {
    var caught: ?PodTestError = None
    try {
        MysqlContainer().withInitSql("  ")
    } catch (e: PodTestException) {
        caught = Some(e.error)
    }

    @Expect(caught.isSome())
    expectMysqlConfigFailure(caught.getOrThrow())
}
