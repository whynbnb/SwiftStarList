import Foundation

struct AboutStrings {
    let aboutTab: String
    let aboutApp: String
    let version: String
    let developer: String
    let openSource: String
    let license: String

    static let zh = AboutStrings(
        aboutTab: "关于",
        aboutApp: "关于 SwiftStarList",
        version: "版本",
        developer: "开发者",
        openSource: "开源地址",
        license: "许可证"
    )

    static let en = AboutStrings(
        aboutTab: "About",
        aboutApp: "About SwiftStarList",
        version: "Version",
        developer: "Developer",
        openSource: "Open Source",
        license: "License"
    )
}
