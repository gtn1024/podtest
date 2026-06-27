package podtest_core

import std.unittest.*
import std.unittest.testmacro.*

// 一段 docker inspect 运行中容器的典型输出（已精简到解析关心的字段）。
let RUNNING_JSON = ##"[{
  "Id": "abc123def456",
  "Name": "/podtest_unit_running",
  "State": {
    "Status": "running",
    "Running": true,
    "ExitCode": 0,
    "Health": {
      "Status": "healthy"
    }
  },
  "NetworkSettings": {
    "IPAddress": "172.17.0.2",
    "Ports": {
      "80/tcp": [{"HostIp": "0.0.0.0", "HostPort": "49154"}]
    }
  }
}]"##

// 已退出容器：Running=false、无 Health。
let EXITED_JSON = ##"[{
  "Id": "exited123",
  "Name": "/podtest_unit_exited",
  "State": {
    "Status": "exited",
    "Running": false,
    "ExitCode": 137
  },
  "NetworkSettings": {
    "IPAddress": "",
    "Ports": {}
  }
}]"##

// 无端口映射的容器（Ports 为空对象）。
let NO_PORTS_JSON = ##"[{
  "Id": "noport123",
  "Name": "/podtest_unit_noport",
  "State": {"Status": "running", "Running": true, "ExitCode": 0},
  "NetworkSettings": {"Ports": {}}
}]"##

@Test
func testParseContainerInfoRunning() {
    let info = ContainerInfo.fromInspectJson(RUNNING_JSON)
    @Expect(info.id == "abc123def456")
    @Expect(info.name == "podtest_unit_running")
    @Expect(info.state == "running")
    @Expect(info.running)
    @Expect(info.exitCode == 0)
    @Expect(info.health.isSome())
    @Expect(info.health.getOrThrow().status == "healthy")
    @Expect(info.ipAddress.isSome())
    @Expect(info.ipAddress.getOrThrow() == "172.17.0.2")
    let binding = info.portBinding("80/tcp")
    @Expect(binding.isSome())
    @Expect(binding.getOrThrow().hostIp == "0.0.0.0")
    @Expect(binding.getOrThrow().hostPort == "49154")
}

@Test
func testParseContainerInfoExited() {
    let info = ContainerInfo.fromInspectJson(EXITED_JSON)
    @Expect(info.state == "exited")
    @Expect(!info.running)
    @Expect(info.exitCode == 137)
    @Expect(info.health.isNone())
    // IPAddress 为空字符串时视为无 IP。
    @Expect(info.ipAddress.isNone())
}

@Test
func testParseContainerInfoWithoutHealth() {
    let info = ContainerInfo.fromInspectJson(EXITED_JSON)
    // State 里没有 Health 字段，health 应为 None 且不抛异常。
    @Expect(info.health.isNone())
}

@Test
func testParseContainerInfoNoPorts() {
    let info = ContainerInfo.fromInspectJson(NO_PORTS_JSON)
    @Expect(info.portBinding("80/tcp").isNone())
    @Expect(info.portBinding("80").isNone())
}

@Test
func testParseContainerInfoInvalidJson() {
    var caught: ?PodTestError = None
    try {
        ContainerInfo.fromInspectJson("not a json")
    } catch (e: PodTestException) {
        caught = Some(e.error)
    }
    @Expect(caught.isSome())
    @Expect(match (caught.getOrThrow()) {
        case InspectFailed(_) => true
        case _ => false
    })
}

@Test
func testContainerInfoPortNormalization() {
    let info = ContainerInfo.fromInspectJson(RUNNING_JSON)
    // "80" 和 "80/tcp" 都应命中同一映射。
    let byBare = info.portBinding("80")
    let bySlash = info.portBinding("80/tcp")
    @Expect(byBare.isSome())
    @Expect(bySlash.isSome())
    @Expect(byBare.getOrThrow().hostPort == "49154")
    @Expect(bySlash.getOrThrow().hostPort == "49154")
    // 不存在的端口。
    @Expect(info.portBinding("443").isNone())
}

@Test
func testNormalizePort() {
    @Expect(ContainerInfo.normalizePort("80") == "80/tcp")
    @Expect(ContainerInfo.normalizePort("80/tcp") == "80/tcp")
    @Expect(ContainerInfo.normalizePort("53/udp") == "53/udp")
}
