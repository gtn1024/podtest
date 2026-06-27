package podtest_core

import std.unittest.*
import std.unittest.testmacro.*
import std.core.Duration

@Test
func testGenericContainerStartStop() {
    let container = GenericContainer("docker.io/library/alpine:latest")
    container.start()
    @Expect(container.isStarted)

    container.stop()
    @Expect(!container.isStarted)
}

@Test
func testGenericContainerWithEnv() {
    let container = GenericContainer("docker.io/library/alpine:latest")
        .env("PODTEST_TEST", "hello")
    container.start()

    container.stop()
}

@Test
func testGenericContainerBuilderChaining() {
    let container = GenericContainer("docker.io/library/alpine:latest")
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
    try (container = GenericContainer("docker.io/library/alpine:latest")) {
        container.start()
        @Expect(container.isStarted)
        @Expect(!container.isClosed())
        closed = container.isClosed()
    }
    @Expect(!closed)
}

@Test
func testGenericContainerClose() {
    let container = GenericContainer("docker.io/library/alpine:latest")
    container.start()
    @Expect(!container.isClosed())
    container.close()
    @Expect(container.isClosed())
}

@Test
func testGenericContainerExecSuccess() {
    try (container = GenericContainer("docker.io/library/alpine:latest").extraArgs(["sleep", "60"])) {
        container.start()
        let result = container.exec(["sh", "-c", "printf podtest-container-exec"])
        @Expect(result.success)
        @Expect(result.exitCode == 0)
        @Expect(result.stdout == "podtest-container-exec")
        @Expect(result.stderr == "")
    }
}

@Test
func testGenericContainerExecNonZeroExit() {
    try (container = GenericContainer("docker.io/library/alpine:latest").extraArgs(["sleep", "60"])) {
        container.start()
        let result = container.exec(["sh", "-c", "printf failed >&2; exit 7"])
        @Expect(!result.success)
        @Expect(result.exitCode == 7)
        @Expect(result.stdout == "")
        @Expect(result.stderr == "failed")
    }
}

@Test
func testGenericContainerExecEmptyCommand() {
    try (container = GenericContainer("docker.io/library/alpine:latest").extraArgs(["sleep", "60"])) {
        container.start()
        var caught: ?PodTestError = None
        try {
            container.exec([])
        } catch (e: PodTestException) {
            caught = Some(e.error)
        }

        @Expect(caught.isSome())
        @Expect(match (caught.getOrThrow()) {
            case ConfigError(_) => true
            case _ => false
        })
    }
}

@Test
func testGenericContainerExecBeforeStart() {
    let container = GenericContainer("docker.io/library/alpine:latest")
    var caught: ?PodTestError = None
    try {
        container.exec(["sh", "-c", "printf should-not-run"])
    } catch (e: PodTestException) {
        caught = Some(e.error)
    }

    @Expect(caught.isSome())
    @Expect(match (caught.getOrThrow()) {
        case ContainerNotFound(_) => true
        case _ => false
    })
}
