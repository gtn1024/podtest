package podtest_mysql

import std.unittest.*
import std.unittest.testmacro.*

@Test
func testMysqlContainerDefaultImage() {
    let mysql = MysqlContainer()
    mysql.start()
    @Expect(mysql.isStarted)
    @Expect(mysql.username == "test")
    @Expect(mysql.password == "test")
    @Expect(mysql.database == "test")
    @Expect(mysql.host == "localhost")

    let connStr = mysql.connectionString()
    @Expect(connStr.contains("mysql://"))
    @Expect(connStr.contains(":3306"))

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
