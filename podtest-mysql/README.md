# PodTest MySQL

MySQL container module for PodTest.

## Usage

```cangjie
import podtest_mysql.*

let mysql = MysqlContainer(
    username: "myuser",
    password: "mypass",
    database: "mydb"
)
mysql.start()

let connStr = mysql.connectionString()
// mysql://myuser:mypass@localhost:PORT/mydb

mysql.stop()
```
