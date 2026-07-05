package podtest_minio

import std.unittest.*
import std.unittest.testmacro.*
import podtest_core.{PodTestError, PodTestException, PresetContainer, InitCommandContainer}

func expectMinioContainerContract(container: PresetContainer) {
    @Expect(container.isStarted)
}

func expectMinioInitCommandContract(cmd: InitCommandContainer) {
    @Expect(cmd.isStarted)
    @Expect(cmd.host == "localhost")
    @Expect(cmd.portNum > 0)
}

func expectMinioInitCommandFailure(error: PodTestError) {
    @Expect(error.toString().contains("InitCommandFailed"))
    @Expect(error.toString().contains("MinIO"))
}

func expectMinioConfigFailure(error: PodTestError) {
    @Expect(error.toString().contains("ConfigError"))
    @Expect(error.toString().contains("init command cannot be empty"))
}

@Test
func testMinioContainerDefault() {
    let minio = MinioContainer()
    minio.start()
    let base: PresetContainer = minio
    expectMinioContainerContract(base)

    let cmd: InitCommandContainer = minio
    expectMinioInitCommandContract(cmd)

    @Expect(minio.accessKey == "test")
    @Expect(minio.secretKey == "testtest")

    let endpoint = minio.endpoint()
    @Expect(endpoint.contains("http://"))
    @Expect(endpoint.contains(":" + minio.port))

    let connStr = minio.connectionString()
    @Expect(connStr.contains("s3://"))
    @Expect(connStr.contains("test:testtest@"))

    minio.stop()
    @Expect(!minio.isStarted)
}

@Test
func testMinioContainerCustomCredentials() {
    let minio = MinioContainer(accessKey: "mykey", secretKey: "mysecret")
    minio.start()

    @Expect(minio.accessKey == "mykey")
    @Expect(minio.secretKey == "mysecret")

    let connStr = minio.connectionString()
    @Expect(connStr.contains("mykey:mysecret@"))

    minio.stop()
}

@Test
func testMinioContainerInitCommand() {
    try (minio = MinioContainer().withInitCommand("mb local/podtest-bucket")) {
        minio.start()
        @Expect(minio.isStarted)

        let result = minio.exec([
            "sh", "-c",
            "mc alias set probe http://127.0.0.1:9000 test testtest && mc ls probe/"
        ])
        @Expect(result.success)
        @Expect(result.stdout.contains("podtest-bucket"))
    }
}

@Test
func testMinioContainerInitCommandFailure() {
    try (minio = MinioContainer().withInitCommand("mb local/Invalid_Bucket!")) {
        var caught: ?PodTestError = None
        try {
            minio.start()
        } catch (e: PodTestException) {
            caught = Some(e.error)
        }

        @Expect(caught.isSome())
        expectMinioInitCommandFailure(caught.getOrThrow())
        @Expect(!minio.isStarted)
    }
}

@Test
func testMinioContainerInitCommandEmpty() {
    var caught: ?PodTestError = None
    try {
        MinioContainer().withInitCommand("  ")
    } catch (e: PodTestException) {
        caught = Some(e.error)
    }

    @Expect(caught.isSome())
    expectMinioConfigFailure(caught.getOrThrow())
}
