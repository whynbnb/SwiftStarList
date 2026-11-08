import SwiftUI

enum SettingsTab: Hashable {
    case general
    case github
    case llm
}

struct SettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    @State private var showToken = false
    @State private var editingProfileID: UUID?
    @State private var selectedTab: SettingsTab
    @Environment(\.openWindow) private var openWindow

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
        }
        .id(settingsManager.languageVersion)
        .frame(width: 480, height: 460)
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
    }

    private var generalTab: some View {
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
                    openWindow(id: "data-management")
                } label: {
                    Label(L.d.openDataManagement, systemImage: "externaldrive")
                }
            }
        }
        .formStyle(.grouped)
    }

    private var githubTab: some View {
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
