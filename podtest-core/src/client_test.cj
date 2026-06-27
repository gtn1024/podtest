package podtest_core

import std.unittest.*
import std.unittest.testmacro.*

@Test
func testContainerClientIsRunning() {
    let config = PodTestConfig()
    let client = ContainerClient(config: config)
    @Expect(client.isRunning())
}

@Test
func testContainerClientPullImage() {
    let config = PodTestConfig()
    let client = ContainerClient(config: config)
    client.pullImage("docker.io/library/alpine:latest")
    @Expect(client.imageExists("docker.io/library/alpine:latest"))
}

@Test
func testContainerClientCreateStartStopRemove() {
    let config = PodTestConfig()
    let client = ContainerClient(config: config)

    let id = client.createContainer("docker.io/library/alpine:latest", name: "podtest-unit-create-test")
    @Expect(!id.isEmpty())

    client.startContainer(id)

    client.stopContainer(id)
    client.removeContainer(id, force: true)
    @Expect(!client.containerExists(id))
}

@Test
func testContainerClientMappedPort() {
    let config = PodTestConfig()
    let client = ContainerClient(config: config)

    let id = client.createContainer(
        "docker.io/library/nginx:alpine",
        name: "podtest-unit-port-test",
        exposedPorts: ["8080:80"]
    )
    client.startContainer(id)

    let port = client.mappedPort(id, "80")
    @Expect(port.isSome())

    client.stopContainer(id)
    client.removeContainer(id, force: true)
}

@Test
func testContainerClientExecSuccess() {
    let config = PodTestConfig()
    let client = ContainerClient(config: config)
    client.removeContainer("podtest-unit-exec-success-test", force: true)

    let id = client.createContainer(
        "docker.io/library/alpine:latest",
        name: "podtest-unit-exec-success-test",
        extraArgs: ["sleep", "60"]
    )
    client.startContainer(id)

    let result = client.execContainer(id, ["sh", "-c", "printf podtest-exec"])
    @Expect(result.success)
    @Expect(result.exitCode == 0)
    @Expect(result.stdout == "podtest-exec")
    @Expect(result.stderr == "")

    client.stopContainer(id)
    client.removeContainer(id, force: true)
}

@Test
func testContainerClientExecNonZeroExit() {
    let config = PodTestConfig()
    let client = ContainerClient(config: config)
    client.removeContainer("podtest-unit-exec-nonzero-test", force: true)

    let id = client.createContainer(
        "docker.io/library/alpine:latest",
        name: "podtest-unit-exec-nonzero-test",
        extraArgs: ["sleep", "60"]
    )
    client.startContainer(id)

    let result = client.execContainer(id, ["sh", "-c", "printf failed >&2; exit 7"])
    @Expect(!result.success)
    @Expect(result.exitCode == 7)
    @Expect(result.stdout == "")
    @Expect(result.stderr == "failed")

    client.stopContainer(id)
    client.removeContainer(id, force: true)
}

@Test
func testContainerClientExecEmptyCommand() {
    let config = PodTestConfig()
    let client = ContainerClient(config: config)

    var caught: ?PodTestError = None
    try {
        client.execContainer("podtest-no-container", [])
    } catch (e: PodTestException) {
        caught = Some(e.error)
    }

    @Expect(caught.isSome())
    @Expect(match (caught.getOrThrow()) {
        case ConfigError(_) => true
        case _ => false
    })
}
