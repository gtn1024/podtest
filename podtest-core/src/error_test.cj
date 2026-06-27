package podtest_core

import std.unittest.*
import std.unittest.testmacro.*

@Test
func testPodTestErrorToString() {
    let err = PodTestError.EngineUnavailable("docker not found")
    @Expect(err.toString() == "EngineUnavailable: docker not found")
}

@Test
func testPodTestErrorCliError() {
    let err = PodTestError.CliError("command failed", 1)
    @Expect(err.toString() == "CliError: command failed (exit code: 1)")
}

@Test
func testPodTestErrorInitSqlFailed() {
    let err = PodTestError.InitSqlFailed("statement failed")
    @Expect(err.toString() == "InitSqlFailed: statement failed")
}

@Test
func testPodTestExceptionConstruction() {
    let err = PodTestError.WaitTimeout("timeout after 30s")
    let ex = PodTestException(err)
    @Expect(ex.message == "WaitTimeout: timeout after 30s")
    @Expect(ex.error == err)
}
