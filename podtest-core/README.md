# podtest-core

Containerized testing library for [Cangjie](https://cangjie-lang.cn/) — core module.

PodTest provides a clean API to manage Docker/Podman containers in your test suite. Spin up databases, message queues, or any service your code depends on, run your tests against real instances, and tear them down automatically.

## Installation

```toml
[dependencies]
  podtest_core = "0.1.0"
```

## Quick Start

```cangjie
package mytest

import std.unittest.*
import std.unittest.testmacro.*
import podtest_core.*

@Test
func testWithNginx() {
    let container = GenericContainer("nginx:alpine")
        .exposedPorts(["8080:80"])
        .withWaitStrategy(TcpWait(port: "80", timeout: Duration.second * 30))

    container.start()
    // Run your tests against localhost:8080
    container.stop()
}
```

## API

### GenericContainer

Fluent builder for managing container lifecycle:

```cangjie
let container = GenericContainer("nginx:alpine")
    .exposedPorts(["8080:80"])
    .env("KEY", "value")
    .volume("/host/path", "/container/path")
    .network("host")
    .withWaitStrategy(TcpWait(port: "80"))
    .withStartupTimeout(Duration.second * 30)
    .withPullPolicy(ImagePullPolicy.Missing)

container.start()
let port = container.mappedPort("80")
let logs = container.logs()
let result = container.exec(["sh", "-c", "printf hello"])
container.stop()
```

`exec` returns an `ExecResult` with `exitCode`, `stdout`, `stderr`, and `success`. Non-zero command exits are returned instead of thrown.

Auto-cleanup with `try-with` (implements `Resource`):

```cangjie
try (container = GenericContainer("nginx:alpine").exposedPorts(["8080:80"])) {
    container.start()
    // container auto-closed when leaving scope
}
```

### Wait Strategies

```cangjie
// TCP port ready
TcpWait(port: "5432", timeout: Duration.second * 60, interval: Duration.second * 1)

// Log pattern match
LogWait(pattern: "ready to accept connections", timeout: Duration.second * 60)

// Composite — all must pass
let strategies = ArrayList<WaitStrategy>()
strategies.add(TcpWait(port: "5432"))
strategies.add(LogWait(pattern: "ready"))
CompositeWait(strategies: strategies)
```

### PodTestSuite

Manage multiple containers as a group:

```cangjie
let suite = PodTestSuite(name: "my-suite")
suite.addContainer(c1).addContainer(c2)
suite.startAll()
suite.stopAll()
```

### ContainerClient

Low-level Docker/Podman CLI client:

```cangjie
let client = ContainerClient(config: PodTestConfig())
client.isRunning()
client.pullImage("alpine:latest")
client.imageExists("alpine:latest")
client.createContainer("alpine:latest", name: "test")
client.startContainer(id)
client.stopContainer(id)
client.removeContainer(id, force: true)
client.containerExists(id)
client.mappedPort(id, "80")
client.containerLogs(id)
client.execContainer(id, ["sh", "-c", "printf hello"])
```

### PodTestConfig

```cangjie
let config = PodTestConfig()
config.host = "127.0.0.1"
config.defaultPullPolicy = ImagePullPolicy.Always
config.removeOnExit = true
config.detectEngine()  // returns ContainerEngine.Docker or .Podman
```

| Option | Default | Description |
|--------|---------|-------------|
| `host` | `"localhost"` | Host address for port mapping |
| `dockerSocketPath` | `"/var/run/docker.sock"` | Docker socket path |
| `podmanSocketPath` | `"/run/podman/podman.sock"` | Podman socket path |
| `defaultPullPolicy` | `Missing` | Image pull policy: `Always`, `Missing`, `Never` |
| `removeOnExit` | `true` | Remove container after stop |
| `label` | `"podtest"` | Label for managed containers |

### Error Handling

```cangjie
try {
    container.start()
} catch (e: PodTestException) {
    match (e.error) {
        case PodTestError.WaitTimeout(msg) => ...
        case PodTestError.ContainerStartFailed(msg) => ...
        case _ => ...
    }
}
```
