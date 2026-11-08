import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum SettingsTab: Hashable {
    case general
    case github
    case llm
    case about
}

struct SettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    @State private var showToken = false
    @State private var editingProfileID: UUID?
    @State private var selectedTab: SettingsTab
    @State private var configStatusText: String?
    @State private var configStatusIsError = false
    @State private var pendingImport: AppConfigArchive?
    @State private var prompt: ConfigPrompt?
    @State private var settingsWindow: NSWindow?

    private enum ConfigPrompt: Identifiable {
        case importConfiguration
        case exportCredentials

        var id: Int {
            switch self {
            case .importConfiguration: return 0
            case .exportCredentials: return 1
            }
        }
    }

    init(settingsManager: SettingsManager, initialTab: SettingsTab = .general) {
        _settingsManager = ObservedObject(wrappedValue: settingsManager)
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            generalTab
                .tabItem { Label(L.s.generalTab, systemImage: "gearshape") }
                .tag(SettingsTab.general)

            githubTab
                .tabItem { Label(L.s.githubSection, systemImage: "network") }
                .tag(SettingsTab.github)

            llmTab
                .tabItem { Label("LLM", systemImage: "sparkles") }
                .tag(SettingsTab.llm)

            AboutView()
                .tabItem { Label(L.a.aboutTab, systemImage: "info.circle") }
                .tag(SettingsTab.about)
        }
        .id(settingsManager.languageVersion)
        .frame(width: 480, height: 460)
        .background(SettingsWindowReader { settingsWindow = $0 })
        .onDisappear {
            settingsManager.isSettingsOpen = false
            if settingsManager.settings.theme == .system {
                NSApp.appearance = nil
                for window in NSApp.windows {
                    window.appearance = nil
                }
            }
        }
        .onAppear {
            settingsManager.isSettingsOpen = true
        }
        .alert(item: $prompt) { prompt in
            switch prompt {
            case .importConfiguration:
                return Alert(
                    title: Text(L.c.importConfiguration),
                    message: Text(L.c.importConfirmation),
                    primaryButton: .default(Text(L.c.importConfiguration)) {
                        applyPendingImport()
                    },
                    secondaryButton: .cancel(Text(L.c.cancel)) {
                        pendingImport = nil
                    }
                )
            case .exportCredentials:
                return Alert(
                    title: Text(L.c.exportConfiguration),
                    message: Text(L.c.credentialsExportWarning),
                    primaryButton: .default(Text(L.c.exportConfiguration)) {
                        // 等警告弹窗完全关闭后再打开保存面板，避免嵌套模态。
                        DispatchQueue.main.async {
                            performExportConfiguration()
                        }
                    },
                    secondaryButton: .cancel(Text(L.c.cancel))
                )
            }
        }
    }

    var generalTab: some View {
        Form {
            Section(L.s.languageSection) {
                Picker(L.s.languageSection, selection: $settingsManager.settings.language) {
                    ForEach(AppLanguage.allCases, id: \.self) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
            }

            Section(L.s.themeSection) {
                Picker(L.s.themeSection, selection: $settingsManager.settings.theme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
            }

            Section(L.d.dataManagement) {
                Button {
                    DataManagementWindowController.shared.show(
                        settingsManager: settingsManager,
                        returnWindow: settingsWindow ?? NSApp.keyWindow ?? NSApp.mainWindow
                    )
                } label: {
                    Label(L.d.openDataManagement, systemImage: "externaldrive")
                }
            }

            Section(L.c.configuration) {
                Toggle(L.c.includeCredentials, isOn: includeCredentialsBinding)

                Text(L.c.includeCredentialsHint)
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 10) {
                    Button {
                        startExportConfiguration()
                    } label: {
                        Label(L.c.exportConfiguration, systemImage: "square.and.arrow.up")
                    }

                    Button {
                        startImportConfiguration()
                    } label: {
                        Label(L.c.importConfiguration, systemImage: "square.and.arrow.down")
                    }

                    Spacer(minLength: 0)
                }

                if let configStatusText {
                    Text(configStatusText)
                        .font(.caption)
                        .foregroundColor(configStatusIsError ? .red : .green)
                }
            }
        }
        .formStyle(.grouped)
    }

    var githubTab: some View {
        Form {
            Section(L.s.githubSection) {
                HStack {
                    if showToken {
                        TextField(L.s.githubToken, text: $settingsManager.settings.githubToken)
                    } else {
                        SecureField(L.s.githubToken, text: $settingsManager.settings.githubToken)
                    }
                    Button(action: { showToken.toggle() }) {
                        Image(systemName: showToken ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.plain)
                }

                ProxyConfigSection(config: $settingsManager.settings.githubProxyConfig)
            }
        }
        .formStyle(.grouped)
    }

    var llmTab: some View {
        Form {
            Section(L.s.llmSection) {
                Picker(L.s.llmProfile, selection: editingProfileBinding) {
                    ForEach(settingsManager.settings.llmConfig.profiles) { profile in
                        Text(profileLabel(profile)).tag(profile.id)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        addProfile()
                    } label: {
                        Label(L.s.addProfile, systemImage: "plus")
                    }
                    .buttonStyle(.borderless)

                    Button {
                        deleteEditingProfile()
                    } label: {
                        Label(L.s.deleteProfile, systemImage: "minus")
                    }
                    .buttonStyle(.borderless)
                    .disabled(settingsManager.settings.llmConfig.profiles.count <= 1)

                    Spacer()

                    if isEditingProfileDefault {
                        Label(L.s.defaultProfile, systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Button(L.s.setDefaultProfile) {
                            if let index = editingProfileIndex {
                                settingsManager.settings.llmConfig.defaultProfileID =
                                    settingsManager.settings.llmConfig.profiles[index].id
                            }
                        }
                        .buttonStyle(.borderless)
                    }
                }

                if let index = editingProfileIndex {
                    TextField(L.s.profileName, text: $settingsManager.settings.llmConfig.profiles[index].name)
                        .autocorrectionDisabled()
                    TextField(L.s.baseURL, text: $settingsManager.settings.llmConfig.profiles[index].baseURL)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                    SecureField(L.s.apiKey, text: $settingsManager.settings.llmConfig.profiles[index].apiKey)
                    TextField(L.s.model, text: $settingsManager.settings.llmConfig.profiles[index].model)
                        .autocorrectionDisabled()
                    ProxyConfigSection(config: $settingsManager.settings.llmConfig.profiles[index].proxyConfig)
                }
            }

            Section(L.s.analysisSection) {
                Toggle(L.s.autoAnalyze, isOn: $settingsManager.settings.autoAnalyze)
                Toggle(L.s.simpleMode, isOn: simpleModeBinding)
                Text(L.s.simpleModeHint)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(L.s.customPrompt) {
                TextEditor(text: customPromptBinding)
                    .font(.system(size: 12))
                    .frame(minHeight: 64)

                Text(L.s.customPromptHint)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            ensureEditingProfile()
        }
        .onChange(of: settingsManager.settings.llmConfig.profiles.map(\.id)) { _, _ in
            ensureEditingProfile()
        }
    }

    private var editingProfileIndex: Int? {
        let profiles = settingsManager.settings.llmConfig.profiles
        if let editingProfileID,
           let index = profiles.firstIndex(where: { $0.id == editingProfileID }) {
            return index
        }
        if let defaultID = settingsManager.settings.llmConfig.defaultProfile?.id,
           let index = profiles.firstIndex(where: { $0.id == defaultID }) {
            return index
        }
        return profiles.indices.first
    }

    private var editingProfileBinding: Binding<UUID> {
        Binding(
            get: {
                editingProfileID
                    ?? settingsManager.settings.llmConfig.defaultProfile?.id
                    ?? settingsManager.settings.llmConfig.profiles.first?.id
                    ?? UUID()
            },
            set: { editingProfileID = $0 }
        )
    }

    private var isEditingProfileDefault: Bool {
        guard let index = editingProfileIndex else { return false }
        let profile = settingsManager.settings.llmConfig.profiles[index]
        return settingsManager.settings.llmConfig.defaultProfile?.id == profile.id
    }

    private var includeCredentials: Bool {
        UserDefaults.standard.object(forKey: "exportIncludesCredentials") as? Bool ?? true
    }

    private var includeCredentialsBinding: Binding<Bool> {
        Binding(
            get: { includeCredentials },
            set: { UserDefaults.standard.set($0, forKey: "exportIncludesCredentials") }
        )
    }

    private var customPromptBinding: Binding<String> {
        Binding(
            get: { settingsManager.settings.llmConfig.customPrompt ?? "" },
            set: { settingsManager.settings.llmConfig.customPrompt = $0.isEmpty ? nil : $0 }
        )
    }

    private var simpleModeBinding: Binding<Bool> {
        Binding(
            get: { settingsManager.settings.llmConfig.simpleMode ?? false },
            set: { settingsManager.settings.llmConfig.simpleMode = $0 }
        )
    }

    private func profileLabel(_ profile: LLMProfile) -> String {
        let name = profile.name.isEmpty ? L.s.unnamedProfile : profile.name
        let isDefault = settingsManager.settings.llmConfig.defaultProfile?.id == profile.id
        return isDefault ? name + L.s.defaultSuffix : name
    }

    private func ensureEditingProfile() {
        let profiles = settingsManager.settings.llmConfig.profiles
        if let editingProfileID, profiles.contains(where: { $0.id == editingProfileID }) {
            return
        }
        editingProfileID = settingsManager.settings.llmConfig.defaultProfile?.id ?? profiles.first?.id
    }

    private func addProfile() {
        let profile = LLMProfile(
            name: "LLM \(settingsManager.settings.llmConfig.profiles.count + 1)",
            baseURL: "",
            apiKey: "",
            model: "",
            proxyConfig: .default
        )
        settingsManager.settings.llmConfig.profiles.append(profile)
        editingProfileID = profile.id
    }

    private func deleteEditingProfile() {
        guard let index = editingProfileIndex,
              settingsManager.settings.llmConfig.profiles.count > 1 else { return }

        let removed = settingsManager.settings.llmConfig.profiles.remove(at: index)
        if settingsManager.settings.llmConfig.defaultProfileID == removed.id {
            settingsManager.settings.llmConfig.defaultProfileID =
                settingsManager.settings.llmConfig.profiles.first?.id
        }

        let profiles = settingsManager.settings.llmConfig.profiles
        if !profiles.isEmpty {
            editingProfileID = profiles[min(index, profiles.count - 1)].id
        }
    }

    // MARK: - Configuration import/export

    private func startExportConfiguration() {
        if includeCredentials {
            prompt = .exportCredentials
        } else {
            performExportConfiguration()
        }
    }

    private func performExportConfiguration() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = configurationFileName

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let archive = AppConfigArchive.make(
                settings: settingsManager.settings,
                includeCredentials: includeCredentials
            )
            try archive.encoded().write(to: url, options: .atomic)
            showConfigStatus(
                includeCredentials
                    ? L.c.exportSucceededWithCredentials
                    : L.c.exportSucceededWithoutCredentials
            )
        } catch {
            showConfigStatus("\(L.c.exportFailed): \(error.localizedDescription)", isError: true)
        }
    }

    private func startImportConfiguration() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)
            pendingImport = try AppConfigArchive.decode(from: data)
            prompt = .importConfiguration
        } catch {
            showConfigStatus("\(L.c.importFailed): \(error.localizedDescription)", isError: true)
        }
    }

    private func applyPendingImport() {
        guard let archive = pendingImport else { return }

        let merged = archive.merged(with: settingsManager.settings)
        settingsManager.settings = merged
        editingProfileID = nil
        ensureEditingProfile()
        pendingImport = nil
        showConfigStatus(L.c.importSucceeded)
    }

    private func showConfigStatus(_ text: String, isError: Bool = false) {
        configStatusText = text
        configStatusIsError = isError

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            guard configStatusText == text, configStatusIsError == isError else { return }
            configStatusText = nil
        }
    }

    private var configurationFileName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "swiftstarlist-config-\(formatter.string(from: Date())).json"
    }
}

struct ProxyConfigSection: View {
    @Binding var config: ProxyConfig

    var body: some View {
        Group {
            Picker(L.s.proxyMode, selection: $config.mode) {
                ForEach(ProxyMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }

            if config.mode == .http || config.mode == .socks {
                TextField(L.s.host, text: $config.host)
                    .textContentType(.URL)
                    .autocorrectionDisabled()
                TextField(L.s.port, value: $config.port, format: .number)
            }
        }
    }
}

/// 读取承载 SwiftUI 设置界面的 NSWindow，用于关闭数据管理后恢复焦点。
private struct SettingsWindowReader: NSViewRepresentable {
    let onWindow: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        SettingsWindowReaderView(onWindow: onWindow)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? SettingsWindowReaderView)?.onWindow = onWindow
    }
}

private final class SettingsWindowReaderView: NSView {
    var onWindow: ((NSWindow?) -> Void)?

    init(onWindow: @escaping (NSWindow?) -> Void) {
        self.onWindow = onWindow
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.onWindow?(self.window)
        }
    }
}
