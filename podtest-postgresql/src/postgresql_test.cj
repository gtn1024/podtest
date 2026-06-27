package podtest_postgresql

import std.unittest.*
import std.unittest.testmacro.*
import podtest_core.{PodTestError, PodTestException, PresetContainer, RdbContainer, RdbInitSqlContainer}

func expectPostgresqlContainerContract(container: PresetContainer) {
    @Expect(container.isStarted)
}

func expectPostgresqlRdbContract(rdb: RdbContainer) {
    @Expect(rdb.isStarted)
    @Expect(rdb.username == "test")
    @Expect(rdb.password == "test")
    @Expect(rdb.database == "test")
    @Expect(rdb.host == "localhost")
    @Expect(rdb.portNum > 0)

    let connStr = rdb.connectionString()
    @Expect(connStr.contains("postgresql://"))
    @Expect(connStr.contains(":" + rdb.port))
}

func withPostgresqlInitSql(rdb: RdbInitSqlContainer<PostgresqlContainer>): PostgresqlContainer {
    rdb.withInitSql("CREATE TABLE podtest_init_items (id INT PRIMARY KEY, name TEXT NOT NULL);")
}

func expectPostgresqlInitSqlFailure(error: PodTestError) {
    @Expect(error.toString().contains("InitSqlFailed"))
    @Expect(error.toString().contains("PostgreSQL"))
}

func expectPostgresqlConfigFailure(error: PodTestError) {
    @Expect(error.toString().contains("ConfigError"))
    @Expect(error.toString().contains("init SQL cannot be empty"))
}

@Test
func testPostgresqlContainerDefaultImage() {
    let pg = PostgresqlContainer()
    pg.start()
    let base: PresetContainer = pg
    expectPostgresqlContainerContract(base)

    let rdb: RdbContainer = pg
    expectPostgresqlRdbContract(rdb)

    pg.stop()
    @Expect(!pg.isStarted)
}

@Test
func testPostgresqlContainerCustomCredentials() {
    let pg = PostgresqlContainer(
        username: "myuser",
        password: "mypass",
        database: "mydb"
    )
    pg.start()

    @Expect(pg.username == "myuser")
    @Expect(pg.password == "mypass")
    @Expect(pg.database == "mydb")

    let connStr = pg.connectionString()
    @Expect(connStr.contains("myuser"))
    @Expect(connStr.contains("mydb"))

    pg.stop()
}

@Test
func testPostgresqlContainerInitSql() {
    try (pg = withPostgresqlInitSql(PostgresqlContainer())
        .withInitSql("INSERT INTO podtest_init_items (id, name) VALUES (1, 'seed');")
        .withInitSql(
            "CREATE TABLE podtest_init_assert (id INT NOT NULL, CONSTRAINT fk_podtest_init FOREIGN KEY (id) REFERENCES podtest_init_items(id));")
        .withInitSql("INSERT INTO podtest_init_assert (id) VALUES (1);")) {
        pg.start()
        @Expect(pg.isStarted)
    }
}

@Test
func testPostgresqlContainerInitSqlFailure() {
    try (pg = PostgresqlContainer().withInitSql("SELECT * FROM podtest_missing_table;")) {
        var caught: ?PodTestError = None
        try {
            pg.start()
        } catch (e: PodTestException) {
            caught = Some(e.error)
        }

        @Expect(caught.isSome())
        expectPostgresqlInitSqlFailure(caught.getOrThrow())
        @Expect(!pg.isStarted)
    }
}

@Test
func testPostgresqlContainerInitSqlEmpty() {
    var caught: ?PodTestError = None
    try {
        PostgresqlContainer().withInitSql("  ")
    } catch (e: PodTestException) {
        caught = Some(e.error)
    }

    @Expect(caught.isSome())
    expectPostgresqlConfigFailure(caught.getOrThrow())
}
