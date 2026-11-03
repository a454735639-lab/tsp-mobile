import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var client: TSPClient
    @State private var showLogoutConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section("服务器") {
                    TextField("服务器地址", text: $client.baseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    Text("Tailscale 内网地址，例如 http://100.66.1.2:3018")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Section("关于") {
                    LabeledContent("客户端", value: "TSP Mobile 1.0")
                    LabeledContent("架构", value: "手机仅展示，计算在 NAS")
                }

                Section {
                    Button("退出登录", role: .destructive) {
                        showLogoutConfirm = true
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("确定退出登录？", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
                Button("退出", role: .destructive) {
                    Task { await client.logout() }
                }
                Button("取消", role: .cancel) {}
            }
        }
    }
}
