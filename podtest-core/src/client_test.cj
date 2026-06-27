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
