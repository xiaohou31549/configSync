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

            Text("面向多仓库 GitHub Actions Secrets / Variables 的本地管理与批量同步工具。已切换到标准 OAuth 浏览器回调登录，授权完成后会通过本机 `127.0.0.1` 回调自动返回应用。")
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

            Text("配置方式：在环境变量中设置 `GITHUB_CLIENT_ID` 与 `GITHUB_CLIENT_SECRET`，或在项目根目录创建 `SecretSync.auth.json`。GitHub OAuth App 的回调地址建议配置为 `http://127.0.0.1/oauth/callback`。")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(40)
        .frame(maxWidth: 520)
    }
}
