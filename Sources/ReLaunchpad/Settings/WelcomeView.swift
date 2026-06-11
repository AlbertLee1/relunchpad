import SwiftUI

/// First-run onboarding: how to summon the Launchpad and which permission
/// the trackpad gesture needs. Reachable later from the menu bar item.
struct WelcomeView: View {
    var onFinish: () -> Void

    @ObservedObject private var pinchMonitor = TriggerCoordinator.shared.pinch
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var systemPinchOn = SystemGestureChecker.systemPinchEnabled

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 6) {
                Image(systemName: "square.grid.3x3.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.tint)
                Text("欢迎使用 ReLaunchpad")
                    .font(.title.bold())
                Text("在 macOS 26+ 找回原版启动台")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 14) {
                triggerRow(
                    icon: "dock.rectangle",
                    title: "点击 Dock 图标",
                    detail: "再次点击或按 Esc 关闭"
                )
                triggerRow(
                    icon: "command",
                    title: "按 ⌥ Option + 空格",
                    detail: "全局快捷键,可在设置中修改"
                )
                triggerRow(
                    icon: "rectangle.inset.topleft.filled",
                    title: "鼠标移到屏幕角落",
                    detail: "触发角默认关闭,可在设置中开启"
                )
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "hand.draw")
                        .font(.system(size: 20))
                        .frame(width: 28)
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("触控板五指抓拢").fontWeight(.medium)
                        if pinchMonitor.status == .active {
                            Text("已就绪 ✓").font(.callout).foregroundStyle(.green)
                        } else {
                            Text("需要「输入监控」权限,授权后重启应用")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if pinchMonitor.status != .active {
                        VStack(alignment: .trailing, spacing: 4) {
                            Button("去授权") {
                                PermissionChecker.openInputMonitoringSettings()
                            }
                            Button("已授权,重启应用") {
                                PermissionChecker.relaunchApp()
                            }
                            .controlSize(.small)
                        }
                    }
                }
                if systemPinchOn {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 18))
                            .frame(width: 28)
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("系统抓拢手势仍开启").fontWeight(.medium)
                            Text("抓拢时会同时打开系统的「应用程序」视图")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("一键关闭") {
                            SystemGestureChecker.disableSystemPinch()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                systemPinchOn = SystemGestureChecker.systemPinchEnabled
                            }
                        }
                    }
                }
            }
            .padding(18)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))

            Text("整理图标:按住拖动即可重排,叠放创建文件夹,按住 ⌥ 进入编辑模式删除应用。布局自动保存。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Toggle("登录时自动启动", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, value in
                        LoginItem.set(value)
                        launchAtLogin = LoginItem.isEnabled
                    }
                Spacer()
                Button("打开设置") {
                    SettingsWindowController.shared.show()
                }
                Button("开始使用") { onFinish() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 480)
    }

    private func triggerRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .frame(width: 28)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.medium)
                Text(detail).font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}

@MainActor
final class WelcomeWindowController {
    static let shared = WelcomeWindowController()

    private var window: NSWindow?

    func showIfFirstRun() {
        guard !Preferences.hasSeenWelcome else { return }
        show()
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: WelcomeView { [weak self] in
                Preferences.hasSeenWelcome = true
                self?.window?.close()
                OverlayWindowController.shared.show()
            })
            let window = NSWindow(contentViewController: hosting)
            window.title = "欢迎使用 ReLaunchpad"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.setContentSize(hosting.view.fittingSize)
            self.window = window
        }
        Preferences.hasSeenWelcome = true
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }
}
