package podtest_postgresql

import std.unittest.*
import std.unittest.testmacro.*
import podtest_core.{PresetContainer, RdbContainer}

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
