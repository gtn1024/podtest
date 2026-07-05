package podtest_mongodb

import std.unittest.*
import std.unittest.testmacro.*
import podtest_core.{PodTestError, PodTestException, PresetContainer, InitCommandContainer}

func expectMongodbContainerContract(container: PresetContainer) {
    @Expect(container.isStarted)
}

func expectMongodbInitCommandContract(cmd: InitCommandContainer) {
    @Expect(cmd.isStarted)
    @Expect(cmd.host == "localhost")
    @Expect(cmd.portNum > 0)
}

func expectMongodbInitCommandFailure(error: PodTestError) {
    @Expect(error.toString().contains("InitCommandFailed"))
    @Expect(error.toString().contains("MongoDB"))
}

func expectMongodbConfigFailure(error: PodTestError) {
    @Expect(error.toString().contains("ConfigError"))
    @Expect(error.toString().contains("init command cannot be empty"))
}

@Test
func testMongodbContainerDefault() {
    let mongo = MongodbContainer()
    mongo.start()
    let base: PresetContainer = mongo
    expectMongodbContainerContract(base)

    let cmd: InitCommandContainer = mongo
    expectMongodbInitCommandContract(cmd)

    @Expect(mongo.username == "test")
    @Expect(mongo.password == "test")

    let connStr = mongo.connectionString()
    @Expect(connStr.contains("mongodb://"))
    @Expect(connStr.contains("test:test@"))
    @Expect(connStr.contains(":" + mongo.port))
    @Expect(connStr.contains("/admin"))

    mongo.stop()
    @Expect(!mongo.isStarted)
}

@Test
func testMongodbContainerCustomCredentials() {
    let mongo = MongodbContainer(username: "myuser", password: "mypass")
    mongo.start()

    @Expect(mongo.username == "myuser")
    @Expect(mongo.password == "mypass")

    let connStr = mongo.connectionString()
    @Expect(connStr.contains("myuser:mypass@"))

    mongo.stop()
}

@Test
func testMongodbContainerInitCommand() {
    try (mongo = MongodbContainer()
        .withInitCommand("db.getSiblingDB('podtest').createCollection('items')")
        .withInitCommand("db.getSiblingDB('podtest').items.insertOne({id: 1, name: 'seed'})")) {
        mongo.start()
        @Expect(mongo.isStarted)

        let result = mongo.exec([
            "mongosh",
            "mongodb://test:test@127.0.0.1:27017/podtest?authSource=admin",
            "--quiet",
            "--eval",
            "db.items.countDocuments()"
        ])
        @Expect(result.success)
        @Expect(result.stdout.trimAscii() == "1")
    }
}

@Test
func testMongodbContainerInitCommandFailure() {
    try (mongo = MongodbContainer()
        .withInitCommand("db.getSiblingDB('podtest').c.insertOne({_id: 1})")
        .withInitCommand("db.getSiblingDB('podtest').c.insertOne({_id: 1})")) {
        var caught: ?PodTestError = None
        try {
            mongo.start()
        } catch (e: PodTestException) {
            caught = Some(e.error)
        }

        @Expect(caught.isSome())
        expectMongodbInitCommandFailure(caught.getOrThrow())
        @Expect(!mongo.isStarted)
    }
}

@Test
func testMongodbContainerInitCommandEmpty() {
    var caught: ?PodTestError = None
    try {
        MongodbContainer().withInitCommand("  ")
    } catch (e: PodTestException) {
        caught = Some(e.error)
    }

    @Expect(caught.isSome())
    expectMongodbConfigFailure(caught.getOrThrow())
}
