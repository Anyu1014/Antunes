import SwiftUI

/// 「关于」页：图标、名字、一句话介绍、作者与当前版本，尾部是移植说明与许可。
/// 对应安卓端 `openAbout()` 的那一页；两端保持同样的信息层级。
struct AboutView: View {
    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
        guard let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String, !build.isEmpty else {
            return short
        }
        return "\(short) (\(build))"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Image("AboutIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 84, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
                    .padding(.top, 24)
                    .padding(.bottom, 14)

                Text("Antunes")
                    .font(.title3.weight(.semibold))
                Text("随心而听的第三方网易云客户端")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                    .padding(.bottom, 20)

                VStack(spacing: 0) {
                    infoRow(icon: "person.crop.circle", title: "作者", value: "Anyu")
                    Divider().padding(.leading, 46)
                    infoRow(icon: "info.circle", title: "当前版本", value: version)
                    Divider().padding(.leading, 46)
                    linkRow(icon: "link", title: "仓库", value: "Anyu1014/Antunes", url: AboutView.repositoryURL)
                }
                .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text("许可证：LGPL-3.0-only")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 22)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }

    static let repositoryURL = URL(string: "https://github.com/Anyu1014/Antunes")!

    private func linkRow(icon: String, title: String, value: String, url: URL) -> some View {
        Button {
            Platform.open(url)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                Text(title)
                Spacer(minLength: 8)
                Text(value)
                    .foregroundStyle(.secondary)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: 22)
            Text(title)
            Spacer(minLength: 8)
            Text(value)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }
}
