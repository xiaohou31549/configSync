import Foundation

public enum SampleData {
    public static let repos: [Repo] = [
        Repo(id: 1, name: "blog-web", fullName: "tough/blog-web", owner: "tough", visibility: .public, defaultBranch: "main", archived: false),
        Repo(id: 2, name: "blog-api", fullName: "tough/blog-api", owner: "tough", visibility: .private, defaultBranch: "main", archived: false),
        Repo(id: 3, name: "deploy-scripts", fullName: "tough/deploy-scripts", owner: "tough", visibility: .private, defaultBranch: "main", archived: false),
        Repo(id: 4, name: "legacy-service", fullName: "tough/legacy-service", owner: "tough", visibility: .private, defaultBranch: "master", archived: true)
    ]

    public static let configItems: [ConfigItem] = [
        ConfigItem(name: "VPS_HOST", type: .secret, value: "203.0.113.10", description: "部署服务器地址"),
        ConfigItem(name: "VPS_SSH_KEY", type: .secret, value: "-----BEGIN OPENSSH PRIVATE KEY-----", description: "部署 SSH 私钥"),
        ConfigItem(name: "DEPLOY_PATH", type: .variable, value: "/srv/apps/blog", description: "目标目录"),
        ConfigItem(name: "IMAGE_NAME", type: .variable, value: "ghcr.io/tough/blog-web", description: "镜像名")
    ]
}
