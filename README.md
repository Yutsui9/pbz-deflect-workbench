# 影之刃零 · 卸势调校台

为《影之刃零》提供独立键鼠招架、连续卸势奖励和可视化调参的 Windows 本地工具。MIT 开源，非官方项目。

## 三步安装

1. 在本仓库 **Releases** 下载 `pbz-deflect-workbench-v…-windows-x64.zip`，完整解压到游戏目录之外。
2. 关闭游戏和旧配置面板，双击 **安装.cmd**，输入 Steam 的 `PBZ` 游戏根目录（其中应有 `platform\steam\PBZ.exe`）。首次安装会下载并校验适配 UE4SS，现有加载器不覆盖；已有参数保留，存档自动复制备份。
3. 双击游戏目录里的 **卸势调校台.exe**，点击 **启用并应用**，从 Steam 启动游戏并进入场景。

不需要联网账号、服务器或运行 Python。面板是 Windows 自带 .NET Framework 的 WinForms 程序。首次下载 UE4SS 需要网络。安装到受系统保护的目录时，需要该目录的写入权限。

安装包脚本可先用文本编辑器审阅。也可在 PowerShell 运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deploy\Install.ps1 -GameRoot 'D:\SteamLibrary\steamapps\common\PBZ' -InstallUE4SS
```

## 启动、关闭和停用

- **启动面板**：双击游戏根目录的 `卸势调校台.exe`；游戏可先开或后开，面板不会替你启动游戏。
- **关闭面板**：点右上角 X。模组继续按已保存设置运行；未点击应用的表单修改不会保存。
- **启用**：点击“启用并应用”。运行中切回游戏通常约 250ms 后接收；未开游戏则下次自动加载。
- **停用**：点击“还原游戏原版”。撤回本模组运行中的输入、数值和反馈修改，并保存停用状态；配置与存档不回滚。
- **退出游戏**：从游戏菜单正常退出。面板与游戏是两个独立进程。
- **卸载**：关闭游戏和面板，双击安装包内的 `卸载.cmd`。安装文件会归档，覆盖前的旧文件会恢复；存档和共享 UE4SS 保留。

安装前已经手动装过同名模组时，卸载会恢复旧版，而不是连旧版一起删除。没有本安装器记录的手动版本，请按[使用说明](docs/使用说明.txt)停用。

## 主要功能与默认值

- 鼠标右键点按招架，长按 G 防御；右键长按不连发。
- 基础窗口 250ms，四档连按倍率均为 1，可分别调节；停止连按恢复间隔 400ms。
- 每次有效点按耗杀气上限 3%；成功额外回气 10%，即时削去敌方韧性上限 10%，不需要追加攻击。
- 连续成功第二次起叠奖励，每层额外回气、削韧各 2%，最多 3 层，6 秒内衔接；落空、普通防御或死亡会断连。
- 成功后保留本次剩余窗口；同次按键多个独立成功结果会发放收益，连胜只增加一次。
- 举刀 1.7 倍、收刀 1.5 倍；可调刀面反光、短金属声和点按上半身动作反馈。
- 当前武器举刀动画被用于 160ms 的上半身抖刀片段，命中和其他战斗反馈优先。无需把游戏动画复制到仓库。
- 配置自动备份，可随时启用或还原原版；键鼠分键，手柄保留原生输入。

## 热加载与排错

**优先用面板“启用并应用”**，面板会显示应用结果。切回游戏后才会继续处理请求。

F5 重读配置和反馈/奖励脚本；F6 输出状态日志；F7 临时停用当前会话。F5 本身没有画面提示，日志中 `Config loaded` 表示已加载。`combat.lua` 核心逻辑及原生 Hook 安装代码变动需要重启游戏。

UE4SS 全局自动重载与本模组 F5 是两套机制。已验证安装会关闭全局重载，避免旧循环重复运行。不要靠开启 `EnableAutoReloadingLuaMods` 修复 F5。

若面板提示无法启动，确认 EXE 放在游戏根目录而不是 `platform\steam`，且安装包完整解压。若游戏无反应，检查 `platform\steam\ue4ss\UE4SS.log` 和加载器是否适配当前游戏版本。

## 兼容性与存档

本机已验证 Windows x64、游戏 build `26266538`、游戏适配 UE4SS `v3.0.1-1188-gf885e8d2`。游戏更新可能改变蓝图字段或接口；不承诺其他版本已验证。

安装器只复制 `ProjectPBZ\Saved` 到本地备份，不切换当前存档、不修改 Steam 云同步。需要独立试验进度时，先关闭云同步、退出游戏，再自行切换备份副本。工作台的“还原原版”不回滚已发生的战斗收益或存档。

内部模组目录 `PBZYanyunGuard` 和旧配置备份目录暂时保留，目的是兼容已有安装；产品名称统一为“卸势调校台”。

## 从源码构建

克隆仓库，在 Windows PowerShell 5.1 或 PowerShell 7 中运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1 -Test
```

使用 Windows 自带 `.NET Framework 4.x` C# 编译器，无需 Visual Studio、NuGet 或额外包管理器。`dist/` 是待安装目录；`artifacts/` 生成可分发 ZIP 和 SHA-256。`-Test` 会运行面板自检和假游戏目录的安装/升级/卸载验证，不修改真实游戏。

源码结构：`src/ControlPanel` 为 C# 面板；`mod/Scripts` 为 Lua 模组；`deploy` 为安装卸载；`tests` 为部署验证。运行时配置以安装后的 `config.lua` 为准。

## 发布流程

1. 修改代码与 `VERSION`，同步面板版本和说明。
2. 运行 `build.ps1 -Test`，在支持的游戏版本中验证输入、动画与实战。
3. 提交代码并推送 `main`；GitHub Actions 自动构建并保存 Windows 安装包。
4. 创建并推送 `v版本号` 标签，例如 `v0.2.4`；工作流自动发布 Release 与校验文件。

Windows 编译和部署测试自动化；游戏战斗与动画只能由实际游戏验证。当前长刀抖刀效果已有玩家确认，其他武器仍需验证。

维护者也可安装 `requirements-dev.txt` 中的 Lupa，运行 `python tests/test_success_chain.py` 与 `python tests/test_tap_motion.py`，检查 Lua 语法、连胜奖励、重复事件、回气上限和动作切换。GitHub Actions 会执行这些模拟检查；安装包用户无需 Python。

## 许可与依赖

本仓库原创 C#、Lua 和部署脚本按 [MIT](LICENSE) 发布，不包含游戏资源、存档、个人日志、反射头文件或第三方 DLL。

UE4SS 是独立的 MIT 项目；安装器从[游戏适配版官方发布页](https://github.com/KintaroModding/ue4ss/releases/tag/v3.0.1-1188-gf885e8d2)下载固定版本并验证 SHA-256。另见 [UE4SS 上游](https://github.com/UE4SS-RE/RE-UE4SS)和[安装文档](https://docs.ue4ss.com/installation-guide)。游戏及其动画、音效属于各自权利人，本项目仅在运行时调用已有资源。
