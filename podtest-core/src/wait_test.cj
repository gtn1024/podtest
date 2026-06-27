package podtest_core

import std.unittest.*
import std.unittest.testmacro.*
import std.core.Duration

@Test
func testWaitStrategyLogWait() {
    let container = GenericContainer("docker.io/library/alpine:latest")
        .extraArgs(["sh", "-c", "echo READY && sleep 60"])
        .withWaitStrategy(LogWait(pattern: "READY", timeout: Duration.second * 10))

    container.start()
    @Expect(container.isStarted)

    container.stop()
}
