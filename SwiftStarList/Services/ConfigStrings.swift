import Foundation

extension L {
    /// 配置导入/导出文案
    static var c: ConfigStrings {
        AppLanguage.resolved == .zh ? .zh : .en
    }
}

struct ConfigStrings {
    let configuration: String
    let exportConfiguration: String
    let importConfiguration: String
    let includeCredentials: String
    let includeCredentialsHint: String
    let credentialsExportWarning: String
    let importConfirmation: String
    let exportSucceeded: String
    let importSucceeded: String
    let importFailed: String
    let exportFailed: String
    let invalidConfigFile: String
    let cancel: String

    static let zh = ConfigStrings(
        configuration: "配置",
        exportConfiguration: "导出配置…",
        importConfiguration: "导入配置…",
        includeCredentials: "包含凭据",
        includeCredentialsHint: "GitHub Token 与 LLM API Key 会以明文写入配置文件。",
        credentialsExportWarning: "导出的文件将包含 GitHub Token 和 LLM API Key 明文。确定继续吗？",
        importConfirmation: "导入后将替换当前语言、外观、分析、代理、GitHub 与 LLM 配置。",
        exportSucceeded: "配置已导出",
        importSucceeded: "配置已导入",
        importFailed: "配置导入失败",
        exportFailed: "配置导出失败",
        invalidConfigFile: "文件不是有效的 SwiftStarList 配置文件。",
        cancel: "取消"
    )

    static let en = ConfigStrings(
        configuration: "Configuration",
        exportConfiguration: "Export Configuration…",
        importConfiguration: "Import Configuration…",
        includeCredentials: "Include credentials",
        includeCredentialsHint: "GitHub Token and LLM API keys will be written to the file in plain text.",
        credentialsExportWarning: "The exported file will contain your GitHub Token and LLM API keys in plain text. Continue?",
        importConfirmation: "Importing will replace the current language, appearance, analysis, proxy, GitHub, and LLM settings.",
        exportSucceeded: "Configuration exported",
        importSucceeded: "Configuration imported",
        importFailed: "Configuration import failed",
        exportFailed: "Configuration export failed",
        invalidConfigFile: "The file is not a valid SwiftStarList configuration file.",
        cancel: "Cancel"
    )
}
