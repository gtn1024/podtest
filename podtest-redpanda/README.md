# PodTest Redpanda

Redpanda (Kafka-API-compatible streaming) container module for PodTest.

## Usage

```cangjie
import podtest_redpanda.*

let rp = RedpandaContainer()
    .withInitCommand("topic create orders -p 3")
rp.start()

let bs = rp.bootstrapServers()
// localhost:PORT

rp.stop()
```

## Init commands

`withInitCommand` queues inline `rpk` commands (run inside the container) before `start()` returns. A failing command (non-zero exit, e.g. a duplicate topic) aborts `start()` with `InitCommandFailed` and cleans up the container.

The container runs in single-node KRaft mode with the official lightweight flags (`--overprovisioned --smp 1 --memory 1G`).
