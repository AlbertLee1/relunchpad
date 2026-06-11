import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    @ObservedObject private var coordinator = TriggerCoordinator.shared
    @ObservedObject private var pinchMonitor = TriggerCoordinator.shared.pinch
    @ObservedObject private var mediaKey = TriggerCoordinator.shared.mediaKey

    @State private var captureLaunchpadKey = Preferences.captureLaunchpadKey
    @State private var hotCorner = Preferences.hotCorner
    @State private var pinchEnabled = Preferences.pinchEnabled
    @State private var pinchFingers = Preferences.pinchFingers
    @State private var showDockIcon = Preferences.showDockIcon
    @State private var gridColumns = Preferences.gridColumns
    @State private var gridRows = Preferences.gridRows
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var showResetConfirm = false

    var body: some View {
        Form {
            Section("唤起方式") {
                KeyboardShortcuts.Recorder("全局快捷键", name: .toggleLaunchpad)

                Toggle("占用 F4 启动台键", isOn: $captureLaunchpadKey)
                    .onChange(of: captureLaunchpadKey) { _, value in
                        Preferences.captureLaunchpadKey = value
                        if value, !PermissionChecker.accessibilityGranted {
                            PermissionChecker.openAccessibilitySettings()
                        }
                        coordinator.applyPreferences()
                    }
                if captureLaunchpadKey, !mediaKey.isActive {
                    Label("需要「辅助功能」权限,授权后请重启应用", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.callout)
                }

                Picker("触发角", selection: $hotCorner) {
                    ForEach(HotCorner.allCases) { corner in
                        Text(corner.label).tag(corner)
                    }
                }
                .onChange(of: hotCorner) { _, value in
                    Preferences.hotCorner = value
                    coordinator.applyPreferences()
                }

                Toggle("触控板抓拢手势", isOn: $pinchEnabled)
                    .onChange(of: pinchEnabled) { _, value in
                        Preferences.pinchEnabled = value
                        coordinator.applyPreferences()
                    }

                if pinchEnabled {
                    Picker("手指数量", selection: $pinchFingers) {
                        Text("四指").tag(4)
                        Text("五指(推荐)").tag(5)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: pinchFingers) { _, value in
                        Preferences.pinchFingers = value
                        coordinator.applyPreferences()
                    }

                    pinchStatusRow

                    Text("提示:系统的四指捏合会打开自带的「应用程序」视图,可在 系统设置 > 触控板 > 更多手势 中关闭,或保持五指与其错开。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("网格") {
                Stepper("每行图标数:\(gridColumns)", value: $gridColumns, in: 4...12)
                    .onChange(of: gridColumns) { _, value in
                        Preferences.gridColumns = value
                        AppLibrary.shared.applyGridPreferences()
                    }
                Stepper("行数:\(gridRows)", value: $gridRows, in: 3...10)
                    .onChange(of: gridRows) { _, value in
                        Preferences.gridRows = value
                        AppLibrary.shared.applyGridPreferences()
                    }
            }

            Section("通用") {
                Toggle("在 Dock 中显示图标(点击可唤起)", isOn: $showDockIcon)
                    .onChange(of: showDockIcon) { _, value in
                        Preferences.showDockIcon = value
                        coordinator.applyPreferences()
                    }
                Toggle("登录时启动", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, value in
                        LoginItem.set(value)
                        launchAtLogin = LoginItem.isEnabled
                    }
                LabeledContent("图标排列") {
                    Button("重置布局…") { showResetConfirm = true }
                }
                .confirmationDialog(
                    "重置图标布局?",
                    isPresented: $showResetConfirm
                ) {
                    Button("重置(系统应用优先,按名称排序)", role: .destructive) {
                        AppLibrary.shared.resetLayout()
                    }
                    Button("取消", role: .cancel) {}
                } message: {
                    Text("将丢弃当前排序与所有文件夹。")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var pinchStatusRow: some View {
        HStack {
            switch pinchMonitor.status {
            case .active:
                Label("手势监听正常", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .waitingForData:
                Label("等待触控板数据…(碰一下触控板)", systemImage: "hourglass")
                    .foregroundStyle(.secondary)
            case .noPermission:
                Label("缺少「输入监控」权限", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Spacer()
                Button("打开系统设置") {
                    PermissionChecker.openInputMonitoringSettings()
                }
            case .off:
                Label("已关闭", systemImage: "circle.slash")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.callout)
    }
}
