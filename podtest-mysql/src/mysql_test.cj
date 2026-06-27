package podtest_mysql

import std.unittest.*
import std.unittest.testmacro.*
import podtest_core.{PresetContainer, RdbContainer}

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
