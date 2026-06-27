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
    .withInitSql("CREATE TABLE items (id INT PRIMARY KEY, name TEXT NOT NULL);")
    .withInitSql("INSERT INTO items (id, name) VALUES (1, 'seed');")
mysql.start()

let connStr = mysql.connectionString()
// mysql://myuser:mypass@localhost:PORT/mydb

mysql.stop()
```

`withInitSql` queues inline SQL statements before `start()`. Statements run in order after the MySQL client is ready; a failing statement aborts `start()` with `InitSqlFailed` and cleans up the container.
