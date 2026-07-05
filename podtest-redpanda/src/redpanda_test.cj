package podtest_redpanda

import std.unittest.*
import std.unittest.testmacro.*
import podtest_core.{PodTestError, PodTestException, PresetContainer, InitCommandContainer}

func expectRedpandaContainerContract(container: PresetContainer) {
    @Expect(container.isStarted)
}

func expectRedpandaInitCommandContract(cmd: InitCommandContainer) {
    @Expect(cmd.isStarted)
    @Expect(cmd.host == "localhost")
    @Expect(cmd.portNum > 0)
}

func expectRedpandaInitCommandFailure(error: PodTestError) {
    @Expect(error.toString().contains("InitCommandFailed"))
    @Expect(error.toString().contains("Redpanda"))
}

func expectRedpandaConfigFailure(error: PodTestError) {
    @Expect(error.toString().contains("ConfigError"))
    @Expect(error.toString().contains("init command cannot be empty"))
}

@Test
func testRedpandaContainerDefault() {
    let rp = RedpandaContainer()
    rp.start()
    let base: PresetContainer = rp
    expectRedpandaContainerContract(base)

    let cmd: InitCommandContainer = rp
    expectRedpandaInitCommandContract(cmd)

    let bs = rp.bootstrapServers()
    @Expect(bs.contains(":"))
    @Expect(bs.contains(rp.port))

    rp.stop()
    @Expect(!rp.isStarted)
}

@Test
func testRedpandaContainerInitCommand() {
    try (rp = RedpandaContainer().withInitCommand("topic create podtest-topic -p 1")) {
        rp.start()
        @Expect(rp.isStarted)

        let result = rp.exec(["rpk", "topic", "list"])
        @Expect(result.success)
        @Expect(result.stdout.contains("podtest-topic"))
    }
}

@Test
func testRedpandaContainerInitCommandFailure() {
    try (rp = RedpandaContainer()
        .withInitCommand("topic create dup-topic -p 1")
        .withInitCommand("topic create dup-topic -p 1")) {
        var caught: ?PodTestError = None
        try {
            rp.start()
        } catch (e: PodTestException) {
            caught = Some(e.error)
        }

        @Expect(caught.isSome())
        expectRedpandaInitCommandFailure(caught.getOrThrow())
        @Expect(!rp.isStarted)
    }
}

@Test
func testRedpandaContainerInitCommandEmpty() {
    var caught: ?PodTestError = None
    try {
        RedpandaContainer().withInitCommand("  ")
    } catch (e: PodTestException) {
        caught = Some(e.error)
    }

    @Expect(caught.isSome())
    expectRedpandaConfigFailure(caught.getOrThrow())
}
