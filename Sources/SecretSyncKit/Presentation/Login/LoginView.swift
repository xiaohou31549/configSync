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

            Text("面向多仓库 GitHub Actions Secrets / Variables 的本地管理与批量同步工具。当前登录链路已切换为 GitHub App 安装与用户授权，浏览器完成后会通过本机 `127.0.0.1` 回调自动返回应用。")
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
                Button("配置 GitHub App") {
                    viewModel.loadAuthSettings()
                    viewModel.showAuthSettings = true
                }
                .buttonStyle(.bordered)

                Text(viewModel.hasSavedGitHubAppConfiguration ? "已检测到本地 GitHub App 配置" : "当前未配置 GitHub App，将回退到 mock 登录")
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

            Text("推荐直接点击上方“配置 GitHub App”保存本地授权信息。当前实现会读取 `GITHUB_APP_ID`、`GITHUB_APP_CLIENT_ID`、`GITHUB_APP_CLIENT_SECRET`、`GITHUB_APP_SLUG`、`GITHUB_APP_PRIVATE_KEY_PATH` 和 `GITHUB_CALLBACK_PATH`。回调配置既支持完整 URL，也支持仅填写 path；其中 `Client Secret` 会存入 macOS Keychain，不会写进本地 `auth.json`。")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(40)
        .frame(maxWidth: 520)
        .sheet(isPresented: $viewModel.showAuthSettings) {
            AuthSettingsSheet(viewModel: viewModel)
        }
    }
}

private struct AuthSettingsSheet: View {
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
                    Text("`Client Secret` 会保存在当前 macOS 用户的 Keychain 中，配置文件只保存 App ID、Client ID、Slug、私钥路径和回调地址。")
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
