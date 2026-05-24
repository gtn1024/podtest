package podtest_core

import std.unittest.*
import std.unittest.testmacro.*
import std.core.Duration

@Test
func testGenericContainerStartStop() {
    let container = GenericContainer("alpine:latest")
    container.start()
    @Expect(container.isStarted)

    container.stop()
    @Expect(!container.isStarted)
}

@Test
func testGenericContainerWithEnv() {
    let container = GenericContainer("alpine:latest")
        .env("PODTEST_TEST", "hello")
    container.start()

    container.stop()
}

@Test
func testGenericContainerBuilderChaining() {
    let container = GenericContainer("alpine:latest")
        .exposedPorts(["8080:80"])
        .env("KEY", "value")
        .volume("/tmp", "/tmp")
        .withStartupTimeout(Duration.second * 30)
        .withPullPolicy(ImagePullPolicy.Missing)
    @Expect(!container.isStarted)
}

@Test
func testGenericContainerResourceAutoClose() {
    var closed = false
    try (container = GenericContainer("alpine:latest")) {
        container.start()
        @Expect(container.isStarted)
        @Expect(!container.isClosed())
        closed = container.isClosed()
    }
    @Expect(!closed)
}

@Test
func testGenericContainerClose() {
    let container = GenericContainer("alpine:latest")
    container.start()
    @Expect(!container.isClosed())
    container.close()
    @Expect(container.isClosed())
}
