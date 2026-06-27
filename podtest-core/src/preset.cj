package podtest_core

import std.core.Resource

public interface PresetContainer <: Resource {
    func start(): Unit
    func stop(): Unit

    prop isStarted: Bool
}
