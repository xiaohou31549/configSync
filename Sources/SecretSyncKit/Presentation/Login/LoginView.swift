import SwiftUI

public struct LoginView: View {
    @ObservedObject var viewModel: AppViewModel

    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("SecretSync")
                .font(.system(size: 34, weight: .bold, design: .rounded))

            Text("面向多仓库 GitHub Actions Secrets 的本地管理与批量同步工具。当前登录链路已切换为 GitHub App 安装与用户授权，浏览器完成后会通过本机 `127.0.0.1` 回调自动返回应用。")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                viewModel.signIn()
            } label: {
                HStack {
                    if viewModel.isSigningIn {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(viewModel.isSigningIn ? "正在打开 GitHub App 安装与授权..." : "连接 GitHub App")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isSigningIn)

            HStack {
                Button(configurationButtonTitle) {
                    viewModel.loadAuthSettings()
                    viewModel.showAuthSettings = true
                }
                .buttonStyle(.bordered)

                Text(configurationStatusText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let message = viewModel.authProgressMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let authorizationURL = viewModel.authorizationURL {
                GroupBox("浏览器安装与授权") {
                    VStack(alignment: .leading, spacing: 10) {
                        LabeledContent("授权地址") {
                            Text(authorizationURL.absoluteString)
                                .textSelection(.enabled)
                        }
                        Button("重新打开 GitHub 页面") {
                            viewModel.openVerificationURL()
                        }
                    }
                }
            }

            Text(configurationFootnote)
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(40)
        .frame(maxWidth: 520)
    }

    private var configurationButtonTitle: String {
        viewModel.isUsingBundledGitHubAppConfiguration ? "高级配置" : "配置 GitHub App"
    }

    private var configurationStatusText: String {
        switch viewModel.authConfigurationSource {
        case .bundledApp:
            "应用已内置 GitHub 连接配置，可直接登录"
        case .environment:
            "已检测到运行时 GitHub App 配置"
        case .localFile:
            "已检测到本地 GitHub App 配置"
        case nil:
            "当前未配置 GitHub App，登录前请先完成配置"
        }
    }

    private var configurationFootnote: String {
        if viewModel.isUsingBundledGitHubAppConfiguration {
            return "当前发布包可内置 GitHub App 配置，普通用户默认只需完成浏览器授权与仓库选择。若需要切换到其他 GitHub App，可通过上方“高级配置”写入本地覆盖值。"
        }
        return "当前实现会优先读取环境变量、本地 `auth.json`，以及发布包内置的 GitHub App 配置。回调配置既支持完整 URL，也支持仅填写 path；本地保存时 `Client Secret` 会直接写入本地 `auth.json`。"
    }
}

struct AuthSettingsSheet: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("GitHub App 配置") {
                    TextField("App ID", text: $viewModel.authSettingsDraft.appID)
                        .textFieldStyle(.roundedBorder)

                    TextField("Client ID", text: $viewModel.authSettingsDraft.clientID)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Client Secret", text: $viewModel.authSettingsDraft.clientSecret)
                        .textFieldStyle(.roundedBorder)

                    TextField("Slug", text: $viewModel.authSettingsDraft.slug)
                        .textFieldStyle(.roundedBorder)

                    TextField("Private Key Path", text: $viewModel.authSettingsDraft.privateKeyPath)
                        .textFieldStyle(.roundedBorder)

                    TextField("Callback URL 或 Path", text: $viewModel.authSettingsDraft.callbackPath)
                        .textFieldStyle(.roundedBorder)
                }

                Section("本地存储说明") {
                    Text("若应用已内置 GitHub App 配置，这里的保存值会作为本地覆盖配置优先使用。`Client Secret` 会与 App ID、Client ID、Slug、私钥路径和回调地址一起保存在本地 `auth.json`。")
                        .font(.footnote)
                    Text("私钥文件不会被复制到应用目录，仍使用你填写的本地路径。请确认该 PEM 文件位于仅当前用户可读的位置。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("GitHub App 回调地址") {
                    Text("请在 GitHub App 中把回调地址配置为 `\(resolvedCallbackValue)`。应用在安装与用户授权时会自动使用本机 loopback 回调。")
                        .textSelection(.enabled)
                        .font(.footnote)

                    Text("本地保存位置：\(viewModel.authSettingsLocation)")
                        .textSelection(.enabled)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("GitHub App 设置")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        viewModel.showAuthSettings = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.isSavingAuthSettings ? "保存中..." : "保存") {
                        viewModel.saveAuthSettings()
                    }
                    .disabled(viewModel.isSavingAuthSettings)
                }

                ToolbarItem(placement: .automatic) {
                    Button("清除配置", role: .destructive) {
                        viewModel.clearAuthSettings()
                    }
                }
            }
        }
        .frame(minWidth: 640, minHeight: 420)
    }

    private var resolvedCallbackValue: String {
        let trimmed = viewModel.authSettingsDraft.callbackPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "http://127.0.0.1/oauth/callback" }
        if trimmed.contains("://") { return trimmed }
        return "http://127.0.0.1\(trimmed.hasPrefix("/") ? trimmed : "/\(trimmed)")"
    }
}
