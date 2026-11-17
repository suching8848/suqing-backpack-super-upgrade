# 更新记录 / Changelog

## 1.0.0-rc.3 穿戴热修 / Equip hotfix

- 传奇行李袋和腰包的 21 对款式可以通过右键重新穿回当前栏位。原生动作直接穿戴当前物品，保留袋内物品、EX 扩容和冷藏数据。
- Restores right-click equipping to the current position for all 21 Legendary duffel and waist-pack pairs. The native action equips the existing item, preserving its contents, EX capacity upgrade, and refrigeration data.

## 1.0.0-rc.3

- 新增行李袋、腰包、挎包和三个开封刀箱的 56 个传奇容器 ID，传奇超级升级合计 66 个 ID。
- 传奇行李袋高低背和腰包前后共 21 对换位保留容器内容及 EX 记录。已有非传奇 EX 仍可还原。
- Adds 56 Legendary container IDs across duffels, waist packs, satchels and opened cases, bringing the number of upgrade targets to 66.
- Preserves contents and EX records across all 21 duffel and waist-pack position pairs. Existing non-Legendary EX remains restorable.

## 2026-11-02 源码整理 / Source migration

- 保留 1.0.0-rc.2 安装包的全部 26 个文件及其原 Mod ID、运行逻辑、配方、翻译、资源和版本。
- 添加完整中英使用说明、主模组与独立补丁对应关系、来源说明、可移植打包与验证入口。未执行安装、配置迁移或公开工坊发布。
- Preserves all 26 files of the 1.0.0-rc.2 installable package, including Mod ID, runtime logic, recipes, translations, assets and version.
- Adds complete Chinese/English usage, companion-patch mapping, provenance and portable package/validation entry points. No installation, configuration migration or public Workshop upload was performed.

## 离线检查 / Offline checks

EX core: 28 cases / 162 assertions; crafting transactions: 25 cases / 1520 assertions; native recipe parser: 32 assertions.

本次没有启动游戏，离线通过不等于完整游戏验收。 / The game was not launched; offline success does not establish full in-game acceptance.
