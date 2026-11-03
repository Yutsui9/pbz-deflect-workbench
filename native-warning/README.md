> 状态：beta2 已撤回，实机出现大块棋盘格。当前源码修正包身份冲突，尚未验证游戏渲染，不应作为可用版本发布或安装。

# 影之刃零 · 独立预警换色 1.0.0-beta3-candidate

蓝光卸势预警改为红色，红光闪避预警改为金黄；同步修改对应简体中文教学提示。独立资源 Mod，无需 UE4SS、Lua、ReShade 或卸势调校台。

## 安装与卸载

退出游戏，完整解压安装包到游戏目录以外，运行“安装.cmd”。或手动把包内 ProjectPBZ 文件夹合并到游戏根目录，最终有 `ProjectPBZ/Content/Paks/~mods/PBZWarningColors/PBZWarningColors_P.pak/.utoc/.ucas` 三个文件。启动游戏生效。

运行“卸载.cmd”归档本包文件并恢复安装前同名文件；手动安装可移出上述 PBZWarningColors 文件夹。每次装卸后重启游戏。不提供游戏运行中的开关。

可与卸势调校台 v0.3.0 同用，卸势的启用/还原不会改变本包。使用旧合并版时先升级卸势调校台；不可同时开启旧 Lua 换色脚本和本包。

## 验证范围

基于 Steam build 26266538 / UE 5.7.4 制作。六种目标资源完成无修改二进制往返检查、修改范围检查、粒子曲线透明度/白色闪光检查、容器校验和打包读回比对。非视觉导出（粒子脚本、音频逻辑、系统设置）保持原字节。

这是待实机验证版本：未确认实际金黄光外观、所有战斗场景和帧率。beta1 实测金黄预警整圈变白，红色预警正常。beta2 新增预警专用金黄材质副本，修正颜色来源；仍需实机确认结果。游戏更新后需重新核对资源版本。与替换相同六种预警特效或简体中文 Game.locres 的 Mod 可能冲突。

本包不安装、不停用、不卸载 UE4SS。若还使用卸势或其他 Lua 模组，应保留它；只装本包的玩家无需安装它。

## 实现与来源

只覆盖 Common/NS_AttackAlert_Blue_001、Blue_002、Red_001、Red_004，以及 Hun/NS_AttackAlertHun_Blue_001、Red_001；预警资源来自本地合法安装。新增仅供这三种金黄预警引用的材质副本，原有共享材质不覆盖。简体中文本地化只修改一个原有教学条目。

开发工具：[retoc](https://github.com/trumank/retoc)、[repak](https://github.com/trumank/repak)、[UAssetAPI](https://github.com/atenfyr/UAssetAPI)、[游戏类型映射](https://github.com/KintaroModding/phantombladezero_pbzusmap)。这些工具仅用于制作，玩家无需安装。


## 本地开发复现

`prepare_resources.py` 只读原始分卷，在 staged 中建立稀疏文件供 retoc 读取；tools/local-aes.txt 为本机资源解包信息，不随安装包分发。使用公开 retoc 0.1.5、repak 0.2.3、UAssetAPI 1.1.0、ZstdSharp.Port 0.8.1 与本游戏 usmap。构建脚本需要 PowerShell 7 / Python；安装包只需 Windows 自带 PowerShell 5.1。

提取源预警资产到 legacy、其精确引用的材质实例到 material-original（保留包目录）、源简体中文文本到 text-original 后运行 `build.ps1`。PatchWarnings.cs 直接在内存编辑属性，禁止用 JSON 往返替代：Niagara 自定义属性的 JSON 序列化会丢失字段。patch.ps1 会验证无修改的导出数据字节完全一致，verify.ps1 检查非视觉导出、曲线透明度和白闪保留。
