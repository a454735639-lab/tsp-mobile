import SwiftUI

/// 登录页。TSP 只有一个密码，没有用户名。
struct LoginView: View {
    @EnvironmentObject private var client: TSPClient
    @State private var password = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 10) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 56, weight: .semibold))
                        .foregroundStyle(TSPTheme.accent)
                    Text("TSP 量化")
                        .font(.largeTitle.bold())
                    Text("连接你的 NAS 面板")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 14) {
                    TextField("服务器地址", text: $client.baseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .textFieldStyle(.roundedBorder)

                    SecureField("登录密码", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.go)
                        .onSubmit { Task { await doLogin() } }

                    if let error {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        Task { await doLogin() }
                    } label: {
                        Group {
                            if busy {
                                ProgressView().tint(.white)
                            } else {
                                Text("登录").bold()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .background(TSPTheme.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(busy || password.isEmpty)
                }
                .padding(.horizontal, 4)

                Spacer()

                Text("所有计算在 NAS 上完成，手机仅做展示与操作")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
        }
    }

    private func doLogin() async {
        busy = true
        error = nil
        defer { busy = false }
        do {
            try await client.login(password: password)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
