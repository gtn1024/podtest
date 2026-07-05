# PodTest MinIO

MinIO (S3-compatible object storage) container module for PodTest.

## Usage

```cangjie
import podtest_minio.*

let minio = MinioContainer()
    .withInitCommand("mb local/mybucket")
minio.start()

let endpoint = minio.endpoint()
// http://localhost:PORT

minio.stop()
```

With custom credentials:

```cangjie
let minio = MinioContainer(accessKey: "mykey", secretKey: "mysecret")
minio.start()
// s3://mykey:mysecret@localhost:PORT
minio.stop()
```

## Init commands

`withInitCommand` queues inline `mc` commands (run inside the container) before `start()` returns. Use `local` as the alias — it is reconfigured before every command. A failing command (non-zero exit) aborts `start()` with `InitCommandFailed` and cleans up the container.

MinIO requires the root password to be at least 8 characters; the default is `testtest`.
