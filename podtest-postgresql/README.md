# podtest-postgresql

PostgreSQL container module for [PodTest](https://github.com/gtn1024/podtest) — containerized testing for [Cangjie](https://cangjie-lang.cn/).

Provides a ready-to-use `PostgresqlContainer` that auto-configures a PostgreSQL instance for integration testing.

## Installation

```toml
[dependencies]
  podtest_core = "0.1.0"
  podtest_postgresql = "0.1.0"
```

## Quick Start

```cangjie
package mytest

import std.unittest.*
import std.unittest.testmacro.*
import podtest_postgresql.*

@Test
func testWithPostgres() {
    let pg = PostgresqlContainer(
        username: "myuser",
        password: "mypass",
        database: "mydb"
    )
        .withInitSql("CREATE TABLE items (id INT PRIMARY KEY, name TEXT NOT NULL);")
        .withInitSql("INSERT INTO items (id, name) VALUES (1, 'seed');")
    pg.start()

    let connStr = pg.connectionString()
    // postgresql://myuser:mypass@localhost:PORT/mydb

    pg.stop()
}
```

## API

### PostgresqlContainer

| Parameter | Default | Description |
|-----------|---------|-------------|
| `image` | `"postgres:18-alpine"` | Docker image |
| `username` | `"test"` | PostgreSQL username |
| `password` | `"test"` | PostgreSQL password |
| `database` | `"test"` | Database name |
| `startupTimeout` | `30s` | Max wait time for startup |

Properties:

| Property | Type | Description |
|----------|------|-------------|
| `host` | `String` | `"localhost"` |
| `port` | `String` | Mapped port (string) |
| `portNum` | `Int64` | Mapped port (integer) |
| `username` | `String` | PostgreSQL username |
| `password` | `String` | PostgreSQL password |
| `database` | `String` | Database name |
| `isStarted` | `Bool` | Whether container is running |
| `connectionString()` | `String` | Full connection URL |

Methods:

| Method | Description |
|--------|-------------|
| `withInitSql(sql)` | Queue an inline SQL statement before `start()` |

Init SQL statements run in order after the PostgreSQL client can connect. A failing statement aborts `start()` with `InitSqlFailed` and cleans up the container.

### Wait Strategy

Uses `CompositeWait` internally:
1. `TcpWait(port: "5432")` — TCP port connectivity
2. `LogWait(pattern: "database system is ready to accept connections")` — log readiness
