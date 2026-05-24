package podtest_core

public class ImageManager {
    private let client: ContainerClient
    private let config: PodTestConfig

    public init(client!: ContainerClient) {
        this.client = client
        this.config = client.config
    }

    public func ensureImage(image: String, pullPolicy!: ?ImagePullPolicy = None): Unit {
        let policy = pullPolicy ?? config.defaultPullPolicy
        match (policy) {
            case ImagePullPolicy.Always =>
                client.pullImage(image)
            case ImagePullPolicy.Missing =>
                if (!client.imageExists(image)) {
                    client.pullImage(image)
                }
            case ImagePullPolicy.Never =>
                if (!client.imageExists(image)) {
                    throw PodTestException(PodTestError.ImagePullFailed(
                        "Image '${image}' not found and pull policy is Never"
                    ))
                }
        }
    }
}
