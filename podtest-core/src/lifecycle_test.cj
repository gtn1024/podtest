package podtest_core

import std.unittest.*
import std.unittest.testmacro.*

@Test
func testPodTestSuiteLifecycle() {
    let suite = PodTestSuite(name: "integration-suite")
    let c1 = GenericContainer("alpine:latest")
    let c2 = GenericContainer("alpine:latest")
    suite.addContainer(c1).addContainer(c2)

    suite.startAll()
    @Expect(c1.isStarted)
    @Expect(c2.isStarted)

    suite.stopAll()
    @Expect(!c1.isStarted)
    @Expect(!c2.isStarted)
}
