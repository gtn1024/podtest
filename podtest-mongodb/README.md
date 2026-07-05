# PodTest MongoDB

MongoDB container module for PodTest.

## Usage

```cangjie
import podtest_mongodb.*

let mongo = MongodbContainer()
    .withInitCommand("db.getSiblingDB('mydb').createCollection('items')")
    .withInitCommand("db.getSiblingDB('mydb').items.insertOne({id: 1, name: 'seed'})")
mongo.start()

let connStr = mongo.connectionString()
// mongodb://test:test@localhost:PORT/admin

mongo.stop()
```

With custom credentials:

```cangjie
let mongo = MongodbContainer(username: "myuser", password: "mypass")
mongo.start()
// mongodb://myuser:mypass@localhost:PORT/admin
mongo.stop()
```

## Init commands

`withInitCommand` queues inline JavaScript (run via `mongosh --eval`) before `start()` returns. The root user is created in the `admin` database; connect an application database with `?authSource=admin`:

```
mongodb://test:test@localhost:PORT/mydb?authSource=admin
```
