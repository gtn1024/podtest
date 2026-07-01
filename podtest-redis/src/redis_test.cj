package podtest_redis

import std.unittest.*
import std.unittest.testmacro.*
import podtest_core.{PodTestError, PodTestException, ExecResult, PresetContainer}

func expectRedisContainerContract(container: PresetContainer) {
    @Expect(container.isStarted)
}

func expectRedisInitCommandFailure(error: PodTestError) {
    @Expect(error.toString().contains("InitCommandFailed"))
    @Expect(error.toString().contains("Redis"))
}

func expectRedisConfigFailure(error: PodTestError) {
    @Expect(error.toString().contains("ConfigError"))
    @Expect(error.toString().contains("init command cannot be empty"))
}

@Test
func testRedisContainerDefault() {
    let redis = RedisContainer()
    redis.start()
    let base: PresetContainer = redis
    expectRedisContainerContract(base)

    @Expect(redis.host == "localhost")
    @Expect(redis.portNum > 0)
    @Expect(redis.password.isNone())
    @Expect(redis.database == 0)

    let connStr = redis.connectionString()
    @Expect(connStr.contains("redis://"))
    @Expect(connStr.contains(":" + redis.port))
    @Expect(!connStr.contains("@"))

    redis.stop()
    @Expect(!redis.isStarted)
}

@Test
func testRedisContainerWithPassword() {
    let redis = RedisContainer(password: "secret")
    redis.start()

    @Expect(redis.password == Some("secret"))

    let connStr = redis.connectionString()
    @Expect(connStr.contains(":secret@"))

    // 带密码下 PING 经 ACL 通过
    let result = redis.exec([
        "redis-cli", "-h", "127.0.0.1", "-p", "6379",
        "--no-auth-warning", "-a", "secret", "PING"
    ])
    @Expect(result.success)

    redis.stop()
}

@Test
func testRedisContainerInitCommand() {
    try (redis = RedisContainer()
        .withInitCommand("SET podtest_init_key podtest_init_value")) {
        redis.start()
        @Expect(redis.isStarted)

        // 通过 redis-cli GET 验证 SET 已落地
        let result = redis.exec([
            "redis-cli", "-h", "127.0.0.1", "-p", "6379", "GET", "podtest_init_key"
        ])
        @Expect(result.success)
        @Expect(result.stdout.trimAscii() == "podtest_init_value")
    }
}

@Test
func testRedisContainerInitCommandFailure() {
    try (redis = RedisContainer().withInitCommand("FAKECOMMAND")) {
        var caught: ?PodTestError = None
        try {
            redis.start()
        } catch (e: PodTestException) {
            caught = Some(e.error)
        }

        @Expect(caught.isSome())
        expectRedisInitCommandFailure(caught.getOrThrow())
        @Expect(!redis.isStarted)
    }
}

@Test
func testRedisContainerInitCommandEmpty() {
    var caught: ?PodTestError = None
    try {
        RedisContainer().withInitCommand("  ")
    } catch (e: PodTestException) {
        caught = Some(e.error)
    }

    @Expect(caught.isSome())
    expectRedisConfigFailure(caught.getOrThrow())
}
