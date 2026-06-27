package podtest_postgresql

import std.unittest.*
import std.unittest.testmacro.*

@Test
func testPostgresqlContainerDefaultImage() {
    let pg = PostgresqlContainer()
    pg.start()
    @Expect(pg.isStarted)
    @Expect(pg.username == "test")
    @Expect(pg.password == "test")
    @Expect(pg.database == "test")
    @Expect(pg.host == "localhost")

    let connStr = pg.connectionString()
    @Expect(connStr.contains("postgresql://"))
    @Expect(connStr.contains(":" + pg.port))

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
