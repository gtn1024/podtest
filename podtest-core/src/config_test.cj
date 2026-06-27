package podtest_core

import std.unittest.*
import std.unittest.testmacro.*
import std.core.Duration

@Test
func testPodTestConfigDefaults() {
    let config = PodTestConfig()
    @Expect(config.dockerSocketPath == "/var/run/docker.sock")
    @Expect(config.defaultPullPolicy == ImagePullPolicy.Missing)
    @Expect(config.removeOnExit)
    @Expect(config.host == "localhost")
    @Expect(config.label == "podtest")
}

@Test
func testPodTestConfigCustomValues() {
    let config = PodTestConfig()
    config.host = "127.0.0.1"
    config.defaultPullPolicy = ImagePullPolicy.Always
    config.defaultWaitTimeout = Duration.second * 30
    @Expect(config.host == "127.0.0.1")
    @Expect(config.defaultPullPolicy == ImagePullPolicy.Always)
}

@Test
func testPodTestConfigParseEngine() {
    @Expect(PodTestConfig.parseEngine("docker") == ContainerEngine.Docker)
    @Expect(PodTestConfig.parseEngine("DOCKER") == ContainerEngine.Docker)
    @Expect(PodTestConfig.parseEngine(" podman ") == ContainerEngine.Podman)
}

@Test
func testDockerEngineDetection() {
    let config = PodTestConfig()
    let engine = config.detectEngine()
    let isDocker = engine == ContainerEngine.Docker
    let isPodman = engine == ContainerEngine.Podman
    @Expect(isDocker || isPodman)
}
