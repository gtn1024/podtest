# PodTest

A containerized testing library for [Cangjie](https://cangjie-lang.cn/), inspired by [Testcontainers](https://testcontainers.com/).

PodTest provides a clean API to manage Docker/Podman containers in your test suite — spin up databases, message queues, or any service your code depends on, run your tests against real instances, and tear them down automatically.

[中文文档](README-zh.md)

## Features

- **Docker & Podman** auto-detection via CLI
- **Fluent builder API** for container configuration
- **Wait strategies**: TCP port, log pattern, composite
- **Container exec**: run commands inside started containers
- **Resource interface**: `try-with` auto-cleanup
- **Test suite lifecycle** management with `PodTestSuite`
- **Database modules**: PostgreSQL, MySQL

## Quick Start

### Prerequisites

- Cangjie SDK >= 1.1.0
- Docker or Podman installed and running

### Installation

Add PodTest as a dependency in your `cjpm.toml`:

```toml
[dependencies]
  podtest_core = "0.1.0"
```

For database modules:

```toml
[dependencies]
  podtest_core = "0.1.0"
  podtest_postgresql = "0.1.0"
  podtest_mysql = "0.1.0"
```

### Basic Usage

```cangjie
package mytest

import std.unittest.*
import std.unittest.testmacro.*
import podtest_core.*

@Test
func testWithNginx() {
    let container = GenericContainer("docker.io/library/nginx:alpine")
        .exposedPorts(["8080:80"])
        .withWaitStrategy(TcpWait(port: "80", timeout: Duration.second * 30))

    container.start()
    // Run your tests against localhost:8080
    container.stop()
}
```

Auto-cleanup with `try-with`:

```cangjie
@Test
func testWithAutoCleanup() {
    try (container = GenericContainer("docker.io/library/nginx:alpine").exposedPorts(["8080:80"])) {
        container.start()
        // container auto-closed when leaving scope
    }
}
```

Run commands inside a started container:

```cangjie
let container = GenericContainer("docker.io/library/alpine:latest")
    .extraArgs(["sleep", "60"])
container.start()

let result = container.exec(["sh", "-c", "printf hello"])
if (result.success) {
    // result.stdout == "hello"
}

container.stop()
```

### PostgreSQL

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
    pg.start()

    let connStr = pg.connectionString()
    // postgresql://myuser:mypass@localhost:PORT/mydb

    pg.stop()
}
```

### MySQL

```cangjie
package mytest

import std.unittest.*
import std.unittest.testmacro.*
import podtest_mysql.*

@Test
func testWithMysql() {
    let mysql = MysqlContainer(
        username: "myuser",
        password: "mypass",
        database: "mydb"
    )
    mysql.start()

    let connStr = mysql.connectionString()
    // mysql://myuser:mypass@localhost:PORT/mydb

    mysql.stop()
}
```

### Wait Strategies

```cangjie
// Wait for TCP port
TcpWait(port: "5432", timeout: Duration.second * 30)

// Wait for log pattern
LogWait(pattern: "database system is ready to accept connections")

// Combine multiple strategies
let strategies = ArrayList<WaitStrategy>()
strategies.add(TcpWait(port: "5432"))
strategies.add(LogWait(pattern: "ready to accept connections"))
CompositeWait(strategies: strategies)
```

### Lifecycle Management

```cangjie
let suite = PodTestSuite(name: "integration-suite")
suite.addContainer(container1).addContainer(container2)

suite.startAll()
// All containers are running

suite.stopAll()
// All containers stopped and removed
```

## Configuration

```cangjie
let config = PodTestConfig()
config.host = "127.0.0.1"
config.defaultPullPolicy = ImagePullPolicy.Always
config.removeOnExit = true

let container = GenericContainer("docker.io/library/alpine:latest", config: config)
```

Set `PODTEST_ENGINE` to force an engine instead of auto-detection:

```bash
PODTEST_ENGINE=podman cjpm test
PODTEST_ENGINE=docker cjpm test
```

When using Podman, prefer fully qualified image names such as `docker.io/library/nginx:alpine`, because many Podman installations do not define unqualified search registries.

| Option | Default | Description |
|--------|---------|-------------|
| `host` | `"localhost"` | Host address for port mapping |
| `dockerSocketPath` | `"/var/run/docker.sock"` | Docker socket path |
| `podmanSocketPath` | `"/run/podman/podman.sock"` | Podman socket path |
| `defaultPullPolicy` | `Missing` | Image pull policy: `Always`, `Missing`, `Never` |
| `removeOnExit` | `true` | Remove container after stop |
| `label` | `"podtest"` | Label for managed containers |
