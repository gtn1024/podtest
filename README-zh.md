# PodTest

基于 [仓颉语言](https://cangjie-lang.cn/) 的容器化测试库，灵感来自 [Testcontainers](https://testcontainers.com/)。

PodTest 提供简洁的 API 来管理测试套件中的 Docker/Podman 容器 —— 启动数据库、消息队列或任何你的代码依赖的服务，对真实实例运行测试，然后自动清理。

[English](README.md)

## 特性

- **Docker & Podman** 自动检测，CLI 优先
- **链式构建器 API** 配置容器
- **等待策略**：TCP 端口、日志模式、组合策略
- **容器内执行命令**：在已启动容器里运行命令并获取输出
- **Resource 接口**：`try-with` 自动清理
- **测试套件生命周期** 管理（`PodTestSuite`）
- **数据库模块**：PostgreSQL、MySQL

## 快速开始

### 前置条件

- 仓颉 SDK >= 1.1.0
- Docker 或 Podman 已安装并运行

### 安装

在 `cjpm.toml` 中添加 PodTest 依赖：

```toml
[dependencies]
  podtest_core = "0.1.0"
```

使用数据库模块：

```toml
[dependencies]
  podtest_core = "0.1.0"
  podtest_postgresql = "0.1.0"
  podtest_mysql = "0.1.0"
```

### 基本用法

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
    // 对 localhost:8080 运行测试
    container.stop()
}
```

自动清理（`try-with`）：

```cangjie
@Test
func testWithAutoCleanup() {
    try (container = GenericContainer("docker.io/library/nginx:alpine").exposedPorts(["8080:80"])) {
        container.start()
        // 离开作用域时自动清理容器
    }
}
```

在已启动容器里执行命令：

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

### 等待策略

```cangjie
// 等待 TCP 端口就绪
TcpWait(port: "5432", timeout: Duration.second * 30)

// 等待日志出现指定内容
LogWait(pattern: "database system is ready to accept connections")

// 组合多个策略
let strategies = ArrayList<WaitStrategy>()
strategies.add(TcpWait(port: "5432"))
strategies.add(LogWait(pattern: "ready to accept connections"))
CompositeWait(strategies: strategies)
```

### 生命周期管理

```cangjie
let suite = PodTestSuite(name: "integration-suite")
suite.addContainer(container1).addContainer(container2)

suite.startAll()
// 所有容器已启动

suite.stopAll()
// 所有容器已停止并移除
```

## 配置

```cangjie
let config = PodTestConfig()
config.host = "127.0.0.1"
config.defaultPullPolicy = ImagePullPolicy.Always
config.removeOnExit = true

let container = GenericContainer("docker.io/library/alpine:latest", config: config)
```

设置 `PODTEST_ENGINE` 可以跳过自动检测，强制选择容器引擎：

```bash
PODTEST_ENGINE=podman cjpm test
PODTEST_ENGINE=docker cjpm test
```

使用 Podman 时建议使用 `docker.io/library/nginx:alpine` 这类全限定镜像名，因为很多 Podman 安装没有配置短镜像名搜索仓库。

| 选项 | 默认值 | 说明 |
|------|--------|------|
| `host` | `"localhost"` | 端口映射的主机地址 |
| `dockerSocketPath` | `"/var/run/docker.sock"` | Docker socket 路径 |
| `podmanSocketPath` | `"/run/podman/podman.sock"` | Podman socket 路径 |
| `defaultPullPolicy` | `Missing` | 镜像拉取策略：`Always`、`Missing`、`Never` |
| `removeOnExit` | `true` | 停止后移除容器 |
| `label` | `"podtest"` | 托管容器标签 |
