import AppKit
import SwiftUI

/// 数据管理窗口独立于「设置」窗口管理。
///
/// 打开时记录来源窗口（通常是设置），关闭数据管理后把来源窗口重新置顶，
/// 避免 AppKit 直接回到主界面；设置关闭时数据管理窗口也会保持打开状态。
@MainActor
final class DataManagementWindowController: NSObject, NSWindowDelegate {
    static let shared = DataManagementWindowController()

    private static let frameAutosaveName = "SwiftStarList.DataManagementWindow"

    private var window: NSWindow?
    private weak var returnWindow: NSWindow?
    private var closeObserver: NSObjectProtocol?

    private override init() {
        super.init()
    }

    func show(settingsManager: SettingsManager, returnWindow: NSWindow? = nil) {
        if let returnWindow, returnWindow !== window {
            self.returnWindow = returnWindow
        } else if self.returnWindow == nil,
                  let keyWindow = NSApp.keyWindow,
                  keyWindow !== window {
            self.returnWindow = keyWindow
        }

        if let window {
            present(window)
            return
        }

        let rootView = DataManagementView(settingsManager: settingsManager)
            .environmentObject(settingsManager)
            .preferredColorScheme(settingsManager.settings.theme.resolvedColorScheme)

        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = L.d.dataManagement
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 900, height: 620))
        window.minSize = NSSize(width: 820, height: 560)
        window.isReleasedWhenClosed = false
        // 跟随当前 Space，并在全屏主窗口上也能显示。
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.delegate = self

        // 记忆窗口大小与位置；只有首次打开时才居中。
        _ = window.setFrameAutosaveName(Self.frameAutosaveName)
        if window.setFrameUsingName(Self.frameAutosaveName) {
            clampToMinimumSize(window)
        } else if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            let origin = NSPoint(
                x: visible.midX - window.frame.width / 2,
                y: visible.midY - window.frame.height / 2
            )
            window.setFrameOrigin(origin)
        } else {
            window.center()
        }

        self.window = window
        installCloseObserver()
        present(window)
        schedulePresent(window)
    }

    /// 任意其他窗口关闭后调用，把仍然打开的数据管理窗口重新置顶。
    private func bringToFrontIfVisible() {
        guard let window, NSApp.keyWindow !== window else { return }
        present(window)
    }

    private func present(_ window: NSWindow) {
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private func schedulePresent(_ window: NSWindow) {
        Task { @MainActor [weak self, weak window] in
            for delay in [100, 250] {
                try? await Task.sleep(for: .milliseconds(delay))
                guard let self, let window, self.window === window else { return }
                if NSApp.keyWindow !== window {
                    self.present(window)
                }
            }
        }
    }

    private func clampToMinimumSize(_ window: NSWindow) {
        let minSize = window.minSize
        var frame = window.frame
        var changed = false

        if frame.width < minSize.width {
            frame.size.width = minSize.width
            changed = true
        }
        if frame.height < minSize.height {
            frame.size.height = minSize.height
            changed = true
        }

        if changed {
            window.setFrame(frame, display: false)
        }
    }

    private func installCloseObserver() {
        guard closeObserver == nil else { return }

        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let closingWindowNumber = (note.object as? NSWindow)?.windowNumber ?? -1

            Task { @MainActor in
                guard let self, let window = self.window else { return }
                // 数据管理窗口自己关闭时不需要再置顶。
                guard window.windowNumber != closingWindowNumber else { return }

                // 等主窗口完成 key/main 切换后再置顶，避免又被压回去。
                // 多试一次，覆盖 SwiftUI/Settings 窗口延迟完成的时序。
                for delay in [50, 250] {
                    try? await Task.sleep(for: .milliseconds(delay))
                    self.bringToFrontIfVisible()
                }
            }
        }
    }

    private func removeCloseObserver() {
        if let closeObserver {
            NotificationCenter.default.removeObserver(closeObserver)
        }
        closeObserver = nil
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // 在真正关闭之前先把设置窗口设为 key，避免关闭后 AppKit
        // 短暂把主界面设为 key 再切回来造成闪烁。
        if let target = returnWindow, target.isVisible {
            target.makeKeyAndOrderFront(nil)
        }
        return true
    }

    func windowWillClose(_ notification: Notification) {
        if let closingWindow = notification.object as? NSWindow {
            closingWindow.saveFrame(usingName: Self.frameAutosaveName)
        }

        removeCloseObserver()
        window = nil

        guard let target = returnWindow, target.isVisible else {
            returnWindow = nil
            return
        }
        returnWindow = nil

        // 如果 windowShouldClose 没能恢复（例如代码直接 close），这里补一次。
        if NSApp.keyWindow !== target {
            target.makeKeyAndOrderFront(nil)
        }

        // 兜底检查：如果关闭流程结束后 key 又变了，再恢复一次。
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            guard target.isVisible, NSApp.keyWindow !== target else { return }
            target.makeKeyAndOrderFront(nil)
        }
    }
}
