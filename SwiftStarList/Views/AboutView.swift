import SwiftUI
import AppKit

struct AboutView: View {
    var body: some View {
        VStack(spacing: 8) {
            if let icon = AppInfo.icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 72, height: 72)
            } else {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
            }

            Text(AppInfo.appName)
                .font(.system(size: 22, weight: .bold))

            Text("\(L.a.version) \(AppInfo.versionText)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()
                .padding(.horizontal, 48)
                .padding(.vertical, 6)

            VStack(alignment: .leading, spacing: 9) {
                infoRow(L.a.developer, value: AppInfo.developer)

                linkRow(
                    L.a.openSource,
                    title: "github.com/whynbnb/SwiftStarList",
                    url: AppInfo.repositoryURL
                )

                linkRow(
                    L.a.license,
                    title: "MIT License",
                    url: AppInfo.licenseURL
                )
            }

            Text(AppInfo.copyright)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.top, 4)

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 68, alignment: .trailing)

            Text(value)
                .font(.caption)
                .textSelection(.enabled)

            Spacer(minLength: 0)
        }
    }

    private func linkRow(_ label: String, title: String, url: URL) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 68, alignment: .trailing)

            Link(title, destination: url)
                .font(.caption)

            Spacer(minLength: 0)
        }
    }
}
