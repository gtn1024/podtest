package podtest_core

public interface RdbContainer <: PresetContainer {
    prop host: String
    prop port: String
    prop portNum: Int64
    prop username: String
    prop password: String
    prop database: String

    func connectionString(): String
}

public interface RdbInitSqlContainer<T> <: RdbContainer {
    func withInitSql(sql: String): T
}
