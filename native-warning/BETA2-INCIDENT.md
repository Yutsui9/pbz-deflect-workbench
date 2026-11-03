# beta2 回撤记录

2026-11-03：用户实机反馈特效出现大块棋盘格。已卸载本机独立资源包（含改色教学文本），原版游戏文件未修改；GitHub beta2 转为草稿。

确认的实现错误：GoldMaterials.cs 只更新 NameMap 和导出名称，遗漏 UAsset.FolderName。14 个新增材质的包头仍使用原始共享材质包名。retoc 的 create_asset_builder 按 legacy summary.package_name 计算包 ID，独立文件名不足以隔离包身份。

修正：同步修改 FolderName，并在 Verify 中要求副本包名恰为原包名加 _PBZGold。新增检查已在旧 beta2 上失败（复现错误）。此前 payload 字节往返检查无法验证包身份，不能当作实机渲染正确的依据。

候选版只在工作目录构建，禁止当作已验证修复发布。尚需核对打包后的包身份、材质导入/导出引用以及实机渲染，尤其是着色器加载。

技术依据：https://github.com/trumank/retoc/blob/master/retoc/src/zen_asset_conversion.rs

候选包静态复核：旧 beta2 被新增身份检查拒绝；修正后完整构建通过，容器读回的 14 个材质包路径及导出名均与各自 _PBZGold 文件名一致。未安装候选包，未做实机渲染验证。
