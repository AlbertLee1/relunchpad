# ReLaunchpad

在 macOS 26 (Tahoe) 及以上版本完整复刻被 Apple 移除的原版 Launchpad。

模糊壁纸背景 · 分页网格 · 搜索 · 拖拽排序 · 文件夹(按类别自动命名)· 抖动模式删除应用 ·
右键菜单 · 布局持久化,支持四种唤起方式:

| 唤起方式 | 默认状态 | 说明 |
|---|---|---|
| Dock 图标点击 | 开启 | 再次点击或按 Esc 关闭 |
| 全局快捷键 | ⌥Space | 设置中可自定义(基于 Carbon 热键,无需权限) |
| 触发角 | 关闭 | 设置中选择屏幕角落,停留 0.25s 触发 |
| 触控板抓拢手势 | 五指 | 抓拢打开、张开关闭,需要「输入监控」权限 |

## 构建与运行

```bash
make app      # swift build -c release → 组装并签名 ReLaunchpad.app
open ReLaunchpad.app
make test     # 单元测试(布局 reconcile / 级联、几何命中、捏合识别、搜索排序)
```

### 签名证书(重要)

macOS 的 TCC 权限(输入监控等)锚定在代码签名上。ad-hoc 签名每次构建都会变,
导致每次重编译都要重新授权。首次构建前创建一张自签证书(本仓库脚本会自动使用):

```bash
# 生成并导入名为 "ReLaunchpad Dev" 的自签代码签名证书
openssl req -x509 -newkey rsa:2048 -keyout /tmp/rl-key.pem -out /tmp/rl-cert.pem \
  -days 3650 -nodes -subj "/CN=ReLaunchpad Dev" \
  -addext "keyUsage=digitalSignature" -addext "extendedKeyUsage=codeSigning"
openssl pkcs12 -export -out /tmp/rl-dev.p12 -inkey /tmp/rl-key.pem -in /tmp/rl-cert.pem -passout pass:relaunchpad
security import /tmp/rl-dev.p12 -k ~/Library/Keychains/login.keychain-db -P relaunchpad -T /usr/bin/codesign
security add-trusted-cert -p codeSign -k ~/Library/Keychains/login.keychain-db /tmp/rl-cert.pem
```

### 本机工具链修复(如适用)

部分 CommandLineTools 安装中混有过期的 `*.private.swiftinterface`,会导致所有
SPM manifest 编译失败。无 sudo 的绕过方案(Makefile 自动启用):

```bash
./Scripts/fix-toolchain.sh   # 复制修复后的 manifest API 到 ~/.relaunchpad-toolchain
```

彻底修复(需要 sudo):见脚本内注释。

## 权限

- **输入监控**:仅触控板手势需要。首次启用时系统会弹窗;也可在
  系统设置 > 隐私与安全性 > 输入监控 中手动勾选 ReLaunchpad,然后重启应用。
- 快捷键、触发角、Dock 点击均**不需要**任何权限。

## 编辑模式(抖动)

与原版一致:**按住图标拖动**或**按住 ⌥ Option** 进入抖动模式,可删除的应用左上角
出现 ✕(移到废纸篓;系统应用不可删)。按 Esc、点击空白处或松开 Option 退出。
图标右键菜单提供「在 Finder 中显示」与「移到废纸篓」。

## 与系统手势的冲突

macOS 26 把「拇指与三指捏合」绑定到自带的“应用程序”视图。ReLaunchpad 默认用
**五指**错开;若想用四指,建议在 系统设置 > 触控板 > 更多手势 中关闭系统手势。

## 架构速览

```
Sources/ReLaunchpad/
├── App/        应用入口、Dock reopen、菜单栏项、设置窗口
├── Window/     无边框全屏覆盖窗(毛玻璃、Esc/失焦关闭、缩放动画)
├── Apps/       应用枚举(Spotlight + 目录扫描兜底)、图标缓存、中央模型
├── Layout/     布局 JSON 持久化、reconcile(增删应用)、溢出级联
├── Grid/       分页网格、搜索、拖拽状态机(模型落手才变更)、文件夹
├── Triggers/   热键 / 触发角 / 五指捏合(私有框架隔离于单文件)/ 协调器
├── Settings/   偏好与设置界面
└── Support/    TCC 权限检查、登录自启
```

调试参数:`--show`(启动即打开)、`--search <词>`、`--demo-drag`(驱动拖拽状态机)。

## 已知限制

- 五指手势依赖私有 MultitouchSupport 框架(经 OpenMultitouchSupport 封装),
  未来系统更新可能失效;失效时手势自动降级关闭,其余唤起方式不受影响。
- 拖拽需先按住约 0.25s 再移动(原版 Launchpad 为即按即拖)。
- 本地构建未公证;若分发给他人需 `xattr -d com.apple.quarantine ReLaunchpad.app`
  或右键打开。
