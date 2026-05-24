package podtest_core

import std.collection.ArrayList

public class PodTestSuite {
    private let containers: ArrayList<GenericContainer> = ArrayList<GenericContainer>()
    private let name: String

    public init(name!: String = "PodTest") {
        this.name = name
    }

    public func addContainer(container: GenericContainer): PodTestSuite {
        containers.add(container)
        return this
    }

    public func startAll(): Unit {
        for (c in containers) {
            c.start()
        }
    }

    public func stopAll(): Unit {
        for (c in containers) {
            try {
                c.stop()
            } catch (_: Exception) {}
        }
    }
}
