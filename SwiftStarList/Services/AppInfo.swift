import AppKit

@MainActor
enum AppInfo {
    static let appName = "SwiftStarList"
    static let developer = "whynbnb"
    static let repositoryURL = URL(string: "https://github.com/whynbnb/SwiftStarList")!
    static let licenseURL = URL(string: "https://github.com/whynbnb/SwiftStarList/blob/main/LICENSE")!

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.1"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "2"
    }

    static var versionText: String {
        "\(version) (\(build))"
    }

    static var copyright: String {
        "© 2026 \(developer)"
    }

    static var icon: NSImage? {
        NSApp.applicationIconImage ?? NSImage(named: NSImage.applicationIconName)
    }

    static func showAboutPanel() {
        let credits = NSMutableAttributedString()
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraph
        ]

        credits.append(NSAttributedString(
            string: "\(L.a.developer): \(developer)\n",
            attributes: baseAttributes
        ))

        var linkAttributes = baseAttributes
        linkAttributes[.link] = repositoryURL
        credits.append(NSAttributedString(
            string: "https://github.com/whynbnb/SwiftStarList\n",
            attributes: linkAttributes
        ))

        var licenseAttributes = baseAttributes
        licenseAttributes[.link] = licenseURL
        credits.append(NSAttributedString(
            string: "MIT License\n",
            attributes: licenseAttributes
        ))

        credits.append(NSAttributedString(
            string: copyright,
            attributes: baseAttributes
        ))

        var options: [NSApplication.AboutPanelOptionKey: Any] = [
            .applicationName: appName,
            .applicationVersion: version,
            .version: build,
            .credits: credits
        ]

        if let icon {
            options[.applicationIcon] = icon
        }

        NSApp.orderFrontStandardAboutPanel(options: options)
    }
}
