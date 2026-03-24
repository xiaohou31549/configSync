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

            Text("面向多仓库 GitHub Actions Secrets / Variables 的本地管理与批量同步工具。已接入 GitHub App Device Flow 授权以及真实 Secrets / Variables 同步链路，未配置 `client_id` 时会回退到 mock 登录与 mock 同步。")
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
                    Text(viewModel.isSigningIn ? "正在模拟 Device Flow 登录..." : "Sign in with GitHub")
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

            if let authorization = viewModel.deviceAuthorization {
                GroupBox("授权信息") {
                    VStack(alignment: .leading, spacing: 10) {
                        LabeledContent("User Code") {
                            Text(authorization.userCode)
                                .textSelection(.enabled)
                                .font(.system(.body, design: .monospaced))
                        }
                        LabeledContent("验证地址") {
                            Text(authorization.verificationURI.absoluteString)
                                .textSelection(.enabled)
                        }
                        Button("重新打开 GitHub 授权页") {
                            viewModel.openVerificationURL()
                        }
                    }
                }
            }

            Text("配置方式：在环境变量中设置 `GITHUB_APP_CLIENT_ID`，或在项目根目录创建 `SecretSync.auth.json`，内容示例为 `{\"clientID\":\"Iv1.xxxxx\",\"appName\":\"SecretSync\"}`。")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(40)
        .frame(maxWidth: 520)
    }
}
