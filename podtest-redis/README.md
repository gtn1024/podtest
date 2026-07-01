# PodTest Redis

Redis container module for PodTest.

## Usage

```cangjie
import podtest_redis.*

let redis = RedisContainer()
    .withInitCommand("SET podtest_init_key podtest_init_value")
redis.start()

let connStr = redis.connectionString()
// redis://localhost:PORT/0

redis.stop()
```

With a password:

```cangjie
let redis = RedisContainer(password: "secret")
redis.start()
// redis://:secret@localhost:PORT/0
redis.stop()
```

`withInitCommand` queues inline Redis commands (run via `redis-cli`) before `start()` returns. Commands run in order after the server is ready; a failing command aborts `start()` with `InitCommandFailed` and cleans up the container.