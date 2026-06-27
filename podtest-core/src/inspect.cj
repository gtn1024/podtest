package podtest_core

import std.collection.{HashMap, ArrayList}
import stdx.encoding.json.*

// 解析 docker/podman `inspect` 输出得到的数据结构。
// 当前只保证 docker 的 schema，podman 走同一条解析路径；
// NetworkSettings 等已知有差异的字段处留有 TODO 注释。

/// 单个宿主端口绑定，对应 docker NetworkSettings.Ports 的一项。
public class PortBinding {
    public let hostIp: String
    public let hostPort: String

    public init(hostIp!: String, hostPort!: String) {
        this.hostIp = hostIp
        this.hostPort = hostPort
    }
}

/// 容器健康状态，对应 docker State.Health（仅配了 HEALTHCHECK 的镜像存在）。
public class HealthInfo {
    public let status: String

    public init(status!: String) {
        this.status = status
    }
}

/// `docker inspect` 解析结果。
///
/// 由 `ContainerInfo.fromInspectJson` 从原始 JSON 字符串解析得到，
/// 不依赖容器引擎运行，因此可以纯单元测试覆盖。
public class ContainerInfo {
    public let id: String
    public let name: String
    public let state: String       // State.Status，如 "running" / "exited"
    public let running: Bool       // State.Running
    public let exitCode: Int64     // State.ExitCode
    public let health: ?HealthInfo // State.Health，可缺省 -> None
    // TODO: podman 的 NetworkSettings 网络子结构与 docker 有差异，
    // 目前按 docker schema 解析 NetworkSettings.IPAddress。
    public let ipAddress: ?String
    // TODO: podman NetworkSettings.Ports 结构可能有差异，暂按 docker schema 解析。
    public let ports: HashMap<String, Array<PortBinding>>

    public init(
        id!: String,
        name!: String,
        state!: String,
        running!: Bool,
        exitCode!: Int64,
        health!: ?HealthInfo,
        ipAddress!: ?String,
        ports!: HashMap<String, Array<PortBinding>>
    ) {
        this.id = id
        this.name = name
        this.state = state
        this.running = running
        this.exitCode = exitCode
        this.health = health
        this.ipAddress = ipAddress
        this.ports = ports
    }

    /// 从 `docker inspect <id>` 的 stdout（一个 JSON 数组）解析。
    /// 解析失败抛 `PodTestError.InspectFailed`。
    public static func fromInspectJson(json: String): ContainerInfo {
        let root: JsonValue
        try {
            root = JsonValue.fromStr(json)
        } catch (e: Exception) {
            throw PodTestException(PodTestError.InspectFailed(
                "parse inspect json failed: ${e.message}"
            ))
        }
        return parseRoot(root)
    }

    /// 归一化容器端口查询入参：`"80"` -> `"80/tcp"`，`"80/tcp"` 原样保留。
    public static func normalizePort(port: String): String {
        if (port.contains("/")) {
            return port
        }
        return "${port}/tcp"
    }

    /// 按容器端口（如 "80" 或 "80/tcp"）取首个宿主端口绑定，找不到返回 None。
    public func portBinding(containerPort: String): ?PortBinding {
        let key = ContainerInfo.normalizePort(containerPort)
        if (let Some(bindings) <- ports.get(key)) {
            if (bindings.size > 0) {
                return Some(bindings[0])
            }
        }
        return None
    }

    /// 顶层若是数组则取首元素解析，否则视为解析失败。
    static func parseRoot(root: JsonValue): ContainerInfo {
        match (root) {
            case arr: JsonArray => return firstContainer(arr)
            case _ => throw PodTestException(PodTestError.InspectFailed(
                "inspect json top-level is not an array"
            ))
        }
    }

    /// 取数组首个元素解析；空数组视为解析失败。
    static func firstContainer(arr: JsonArray): ContainerInfo {
        match (arr.get(0)) {
            case Some(first) => return parseContainer(first)
            case None => throw PodTestException(PodTestError.InspectFailed(
                "inspect json returned empty array"
            ))
        }
    }

    /// 解析单个容器对象（inspect 数组的一个元素）。
    static func parseContainer(node: JsonValue): ContainerInfo {
        let obj = node.asObject()

        let id = strField(obj, "Id", "")
        // docker 的 Name 形如 "/podtest_xxx"，去掉前导 '/'。
        let name = strField(obj, "Name", "").removePrefix("/")

        var state = "unknown"
        var running = false
        var exitCode: Int64 = 0
        var health: ?HealthInfo = None
        if (let Some(stateVal) <- obj.get("State")) {
            let stateObj = stateVal.asObject()
            state = strField(stateObj, "Status", "unknown")
            running = boolField(stateObj, "Running", false)
            exitCode = intField(stateObj, "ExitCode", 0)
            health = parseHealth(stateObj)
        }

        var ipAddress: ?String = None
        var ports = HashMap<String, Array<PortBinding>>()
        if (let Some(netVal) <- obj.get("NetworkSettings")) {
            let netObj = netVal.asObject()
            ipAddress = strFieldOpt(netObj, "IPAddress")
            // NetworkSettings.Ports 形如 {"80/tcp": [{"HostIp":"0.0.0.0","HostPort":"49154"}]}
            ports = parsePortsField(netObj)
        }

        return ContainerInfo(
            id: id,
            name: name,
            state: state,
            running: running,
            exitCode: exitCode,
            health: health,
            ipAddress: ipAddress,
            ports: ports
        )
    }

    /// 解析 State.Health（可缺省 -> None）。
    static func parseHealth(stateObj: JsonObject): ?HealthInfo {
        if (let Some(healthVal) <- stateObj.get("Health")) {
            let healthObj = healthVal.asObject()
            return Some(HealthInfo(status: strField(healthObj, "Status", "none")))
        }
        return None
    }

    /// 解析 NetworkSettings.Ports；字段缺失/null/非对象时返回空映射。
    static func parsePortsField(netObj: JsonObject): HashMap<String, Array<PortBinding>> {
        if (let Some(portsVal) <- netObj.get("Ports")) {
            match (portsVal) {
                case o: JsonObject => return parsePorts(o)
                case _ => return HashMap<String, Array<PortBinding>>()
            }
        }
        return HashMap<String, Array<PortBinding>>()
    }

    /// 解析 NetworkSettings.Ports 对象。
    static func parsePorts(portsObj: JsonObject): HashMap<String, Array<PortBinding>> {
        let result = HashMap<String, Array<PortBinding>>()
        for ((key, val) in portsObj.getFields()) {
            // 端口未映射时该值可能是 null；仅在它是 JSON 数组时才解析。
            match (val) {
                case a: JsonArray => result.add(key, parsePortBindings(a))
                case _ => ()
            }
        }
        return result
    }

    /// 解析单个端口的宿主绑定数组。
    static func parsePortBindings(arr: JsonArray): Array<PortBinding> {
        let bindings = ArrayList<PortBinding>()
        for (item in arr.getItems()) {
            let itemObj = item.asObject()
            bindings.add(PortBinding(
                hostIp: strField(itemObj, "HostIp", ""),
                hostPort: strField(itemObj, "HostPort", "")
            ))
        }
        return bindings.toArray()
    }

    /// 取字符串字段，缺省或类型不符时返回默认值。
    static func strField(obj: JsonObject, key: String, defaultValue: String): String {
        if (let Some(v) <- obj.get(key)) {
            match (v) {
                case s: JsonString => return s.getValue()
                case _ => ()
            }
        }
        return defaultValue
    }

    /// 取可选字符串字段，缺省/类型不符/null 时返回 None。
    static func strFieldOpt(obj: JsonObject, key: String): ?String {
        if (let Some(v) <- obj.get(key)) {
            match (v) {
                case s: JsonString => return optionalString(s.getValue())
                case _ => ()
            }
        }
        return None
    }

    /// 空字符串按缺省处理。
    static func optionalString(value: String): ?String {
        if (value.isEmpty()) {
            return None
        }
        return Some(value)
    }

    /// 取布尔字段，缺省或类型不符时返回默认值。
    static func boolField(obj: JsonObject, key: String, defaultValue: Bool): Bool {
        if (let Some(v) <- obj.get(key)) {
            match (v) {
                case b: JsonBool => return b.getValue()
                case _ => ()
            }
        }
        return defaultValue
    }

    /// 取整数字段，缺省或类型不符时返回默认值。
    static func intField(obj: JsonObject, key: String, defaultValue: Int64): Int64 {
        if (let Some(v) <- obj.get(key)) {
            match (v) {
                case i: JsonInt => return i.getValue()
                case _ => ()
            }
        }
        return defaultValue
    }
}
