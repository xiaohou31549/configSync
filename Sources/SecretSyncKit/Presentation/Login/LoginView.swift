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

            Text("面向多仓库 GitHub Actions Secrets 的本地管理与批量同步工具。第一版 MVP 聚焦本地 Secret 的增删改查与同步，授权完成后会通过本机 `127.0.0.1` 回调自动返回应用。")
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
                    Text(viewModel.isSigningIn ? "正在打开 GitHub 浏览器授权..." : "Sign in with GitHub")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isSigningIn)

            HStack {
                Button("配置 OAuth") {
                    viewModel.loadAuthSettings()
                    viewModel.showAuthSettings = true
                }
                .buttonStyle(.bordered)

                Text(viewModel.hasSavedOAuthConfiguration ? "已检测到本地 OAuth 配置" : "当前未配置 OAuth，将回退到 mock 登录")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let message = viewModel.authProgressMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let authorizationURL = viewModel.authorizationURL {
                GroupBox("浏览器授权") {
                    VStack(alignment: .leading, spacing: 10) {
                        LabeledContent("授权地址") {
                            Text(authorizationURL.absoluteString)
                                .textSelection(.enabled)
                        }
                        Button("重新打开 GitHub 授权页") {
                            viewModel.openVerificationURL()
                        }
                    }
                }
            }

            Text("推荐直接点击上方“配置 OAuth”保存本地授权信息。你也可以继续使用环境变量 `GITHUB_CLIENT_ID` / `GITHUB_CLIENT_SECRET`。GitHub OAuth App 的回调地址建议配置为 `http://127.0.0.1/oauth/callback`。")
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
                Section("OAuth 配置") {
                    TextField("Client ID", text: $viewModel.authSettingsDraft.clientID)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Client Secret", text: $viewModel.authSettingsDraft.clientSecret)
                        .textFieldStyle(.roundedBorder)

                    TextField("Callback Path", text: $viewModel.authSettingsDraft.callbackPath)
                        .textFieldStyle(.roundedBorder)

                    TextField("Scopes", text: $viewModel.authSettingsDraft.scopes)
                        .textFieldStyle(.roundedBorder)
                }

                Section("GitHub App 回调地址") {
                    Text("请在 GitHub OAuth App 中把回调地址配置为 `http://127.0.0.1\(normalizedCallbackPath)`。应用在登录时会自动使用本机 loopback 回调，不需要手动输入验证码。")
                        .textSelection(.enabled)
                        .font(.footnote)

                    Text("本地保存位置：\(viewModel.authSettingsLocation)")
                        .textSelection(.enabled)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("OAuth 设置")
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

    private var normalizedCallbackPath: String {
        let trimmed = viewModel.authSettingsDraft.callbackPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "/oauth/callback" }
        return trimmed.hasPrefix("/") ? trimmed : "/\(trimmed)"
    }
}
