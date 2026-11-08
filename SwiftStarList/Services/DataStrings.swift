import Foundation

extension L {
    /// 数据管理界面使用的文案
    static var d: DataStrings {
        AppLanguage.resolved == .zh ? .zh : .en
    }
}

struct DataStrings {
    let dataManagement: String
    let dataManagementSubtitle: String
    let transferTab: String
    let snapshotsTab: String
    let currentData: String
    let currentDataHint: String
    let repositories: String
    let totalStars: String
    let languages: String
    let lastUpdated: String
    let never: String
    let exportJSON: String
    let exportCSV: String
    let importJSON: String
    let createSnapshot: String
    let importHint: String
    let storage: String
    let dataFolder: String
    let revealInFinder: String
    let clearCache: String
    let clearCacheMessage: String
    let clearCacheDone: String
    let importSucceeded: String
    let importBackupCreated: String
    let exportSucceeded: String
    let importFailed: String
    let exportFailed: String
    let snapshotCreated: String
    let snapshots: String
    let snapshot: String
    let snapshotHelp: String
    let newSnapshot: String
    let importSnapshot: String
    let exportSnapshot: String
    let deleteSnapshot: String
    let deleteSnapshotMessage: String
    let selectSnapshot: String
    let noSnapshots: String
    let noSnapshotsHint: String
    let compareWith: String
    let noComparison: String
    let base: String
    let target: String
    let added: String
    let removed: String
    let changed: String
    let netStars: String
    let noDifferences: String
    let noDifferencesHint: String
    let searchRepos: String
    let snapshotName: String
    let created: String
    let delete: String
    let cancel: String
    let close: String
    let language: String
    let description: String
    let lastPush: String
    let topics: String
    let autoBackup: String
    let importedSnapshot: String
    let noData: String
    let invalidFormat: String
    let emptyFile: String
    let writeFailed: String
    let openDataManagement: String

    static let zh = DataStrings(
        dataManagement: "数据管理",
        dataManagementSubtitle: "导入导出 Star 数据，并保存快照以查看和对比变化。",
        transferTab: "导入 / 导出",
        snapshotsTab: "快照",
        currentData: "当前数据",
        currentDataHint: "本地缓存的 Star 仓库数据。",
        repositories: "仓库数量",
        totalStars: "Star 总数",
        languages: "语言数量",
        lastUpdated: "最后更新",
        never: "从未",
        exportJSON: "导出 JSON",
        exportCSV: "导出 CSV",
        importJSON: "导入 JSON",
        createSnapshot: "创建快照",
        importHint: "支持导入 SwiftStarList 备份或 GitHub Star 原始 JSON。导入会替换当前本地数据，并自动创建一份导入前快照。",
        storage: "存储位置",
        dataFolder: "数据目录",
        revealInFinder: "在 Finder 中显示",
        clearCache: "清除本地缓存",
        clearCacheMessage: "这会删除当前缓存的 Star 列表，已保存的快照不受影响。",
        clearCacheDone: "本地缓存已清除",
        importSucceeded: "已导入 %d 个仓库",
        importBackupCreated: "已创建导入前备份快照",
        exportSucceeded: "导出完成",
        importFailed: "导入失败",
        exportFailed: "导出失败",
        snapshotCreated: "已创建快照，包含 %d 个仓库",
        snapshots: "快照",
        snapshot: "快照",
        snapshotHelp: "快照会记录某一时刻的 Star 列表，方便日后查看和对比变化。",
        newSnapshot: "新建快照",
        importSnapshot: "导入快照",
        exportSnapshot: "导出快照",
        deleteSnapshot: "删除快照",
        deleteSnapshotMessage: "该快照将被永久删除，此操作无法撤销。",
        selectSnapshot: "选择一个快照查看详情",
        noSnapshots: "暂无快照",
        noSnapshotsHint: "创建快照，记录 Star 列表随时间的变化。",
        compareWith: "对比",
        noComparison: "不对比",
        base: "基准",
        target: "对比目标",
        added: "新增 Star",
        removed: "取消 Star",
        changed: "有变化",
        netStars: "Star 净变化",
        noDifferences: "两个快照之间没有差异",
        noDifferencesHint: "这段时间内 Star 列表没有新增、移除或变化。",
        searchRepos: "搜索仓库...",
        snapshotName: "快照名称",
        created: "创建时间",
        delete: "删除",
        cancel: "取消",
        close: "关闭",
        language: "语言",
        description: "描述",
        lastPush: "最近推送",
        topics: "标签",
        autoBackup: "导入前自动备份",
        importedSnapshot: "已导入快照「%@」",
        noData: "暂无数据",
        invalidFormat: "文件不是有效的 SwiftStarList 备份或 GitHub Star JSON。",
        emptyFile: "文件中没有仓库数据。",
        writeFailed: "写入文件失败。",
        openDataManagement: "打开数据管理"
    )

    static let en = DataStrings(
        dataManagement: "Data Management",
        dataManagementSubtitle: "Import and export star data, and keep snapshots to review and compare changes.",
        transferTab: "Import / Export",
        snapshotsTab: "Snapshots",
        currentData: "Current Data",
        currentDataHint: "Locally cached starred repositories.",
        repositories: "Repositories",
        totalStars: "Total Stars",
        languages: "Languages",
        lastUpdated: "Last Updated",
        never: "Never",
        exportJSON: "Export JSON",
        exportCSV: "Export CSV",
        importJSON: "Import JSON",
        createSnapshot: "Create Snapshot",
        importHint: "Import a SwiftStarList backup or raw GitHub stars JSON. Importing replaces the current local data and creates a backup snapshot first.",
        storage: "Storage",
        dataFolder: "Data Folder",
        revealInFinder: "Reveal in Finder",
        clearCache: "Clear Local Cache",
        clearCacheMessage: "This removes the current cached star list. Saved snapshots are kept.",
        clearCacheDone: "Local cache cleared",
        importSucceeded: "Imported %d repositories",
        importBackupCreated: "Backup snapshot created",
        exportSucceeded: "Export completed",
        importFailed: "Import failed",
        exportFailed: "Export failed",
        snapshotCreated: "Snapshot created with %d repositories",
        snapshots: "Snapshots",
        snapshot: "Snapshot",
        snapshotHelp: "Snapshots capture the star list at a point in time so you can review and compare changes later.",
        newSnapshot: "New Snapshot",
        importSnapshot: "Import Snapshot",
        exportSnapshot: "Export Snapshot",
        deleteSnapshot: "Delete Snapshot",
        deleteSnapshotMessage: "This snapshot will be permanently deleted. This cannot be undone.",
        selectSnapshot: "Select a snapshot to view details",
        noSnapshots: "No snapshots yet",
        noSnapshotsHint: "Create a snapshot to track how your star list changes over time.",
        compareWith: "Compare with",
        noComparison: "None",
        base: "Base",
        target: "Target",
        added: "New Stars",
        removed: "Removed Stars",
        changed: "Changed",
        netStars: "Net Star Change",
        noDifferences: "No differences between these snapshots",
        noDifferencesHint: "The star list has no additions, removals, or changes in this period.",
        searchRepos: "Search repositories...",
        snapshotName: "Snapshot Name",
        created: "Created",
        delete: "Delete",
        cancel: "Cancel",
        close: "Close",
        language: "Language",
        description: "Description",
        lastPush: "Last Push",
        topics: "Topics",
        autoBackup: "Auto backup before import",
        importedSnapshot: "Imported snapshot \"%@\"",
        noData: "No data",
        invalidFormat: "The file is not a valid SwiftStarList backup or GitHub stars JSON.",
        emptyFile: "No repositories were found in the file.",
        writeFailed: "Failed to write the file.",
        openDataManagement: "Open Data Management"
    )
}
