# 蘇清的背包超级升级模组 / SuQing’s Backpack Super Upgrades Mod

[中文](#中文) · [English](#english)

**1.0.0-rc.2 · Project Zomboid Build 42.21 · 单人候选版 / Single-player release candidate**

## 中文

独立的一次性背包容量翻倍扩展。保留 Mod ID `ExSuQingBackpackSuperUpgrade_4221`、版本、物品与配方；本仓库的 `mods/` 与当前开发安装包逐文件一致。它与[普通容器升级模组](https://github.com/suching8848/suqing-container-upgrade)是不同项目，可以共存并分别还原，不强制依赖普通版。

### 适配和补丁必须一起核对

基础包只直接支持传奇背包的 10 个颜色 ID，以及 `Base.ResidentEvilBackPack` 生化背包，共 11 个 ID。需要自行安装对应的 `LBB42` 或 `RaccoonCityB42` 来源模组；本仓库不打包它们。生化背带、箱子、车厢不在基础范围。

作者当前组合还使用[蘇清的僵尸毁灭工程补丁合集 / SuQing’s Project Zomboid Patches](https://github.com/suching8848/suqing-project-zomboid-patches)。**主模组不包含这些独立兼容层；使用对应组合时需要同时安装所列补丁，不能只下载主模组并期待全部扩展生效。**

| 使用组合 | 需要核对的补丁 Mod ID | 作用和边界 |
| --- | --- | --- |
| 猫又岭 / Nekomata Ridge 的容量包装链 | `CodexNekomataEXCompat_4221` | 保留上游容量逻辑并接通已审计的 EX 包装链；未知包装链拒绝接入 |
| 猫猫背包 EX 强化 | `CodexNekomataEXUpgrade_4221`，并启用上一项兼容补丁 | 独立扩展配方，将该背包原生业务基础 120 对应为 EX 240；不是基础包的第 12 项 |
| HavenFall 大背包 EX、当前新增穿戴容器组合 | `Codex_SuQingWearableCompat_4221` | 另行接入 HavenFall 的 20 个基础/T1/T2/T3 背包 ID；该补丁当前还明确依赖普通容器升级和 HavenFall |

这些是按组合选择的补丁，不应盲目启用整个补丁集合。补丁自己的 `require`、版本检查及加载顺序仍需满足。HavenFall 原生档位升级前先解除 EX，避免新物品丢失付款权益；该约束来自独立补丁。

### 安装与使用

1. 正常退出游戏并保留当前进度恢复方案。
2. 复制 `mods/ExSuQingBackpackSuperUpgrade_4221` 到用户的 `Zomboid/mods`，保留 `42` 和 `common` 结构。不要把仓库根当模组目录。
3. 在目标单人档启用本 Mod ID，按来源模组及所选兼容补丁的 `loadModAfter` 加载。仅使用一种同 ID 安装来源。
4. 将背包卸下，放人物主物品栏，清空物品和全部液体，进入制作分类“蘇清·超级升级”。

单次配方要求裁缝 5、针（保留）、40 干净碎布、20 皮革、20 普通线用量、4 高级鱼线用量。普通满卷线 20 用量，高级鱼线满卷 4 用量。真实扣料验收须关闭免费制作与材料绕过。

升级时将未计角色特性的原生业务基础容量 B 固定为一次性目标 2B；后续取该固定目标与当前原生基础的较大值，再计算角色特性。默认传奇 49→98；生化沙盒基础为 98 时为 98→196。不会因重进、改外观或改沙盒再次连续翻倍。

只叠加普通物品业务容量，保留自重、减重、液体升数、外观、耐久、挂点及原收纳限制。地面方格重量、人物和父容器限制仍有效；原生物理容量提示不一定是实际可用容量。

### 还原、保存与停用

清空并卸下后使用解除配方。完整真实付款返还 50%：20 碎布、10 皮革、10 普通线用量、2 高级鱼线用量。免费制作不产生返料，成功还原清除 EX 自己的状态和账本，不重复返料；普通强化账本独立。

正常保存退出后停用，会关闭 EX 容量效果但保留记录；重新启用恢复同一次强化，不再次收费或翻倍。停用不是还原，不自动返料，建议先清空背包；满载停用后的超载转出、显示与存读档仍需实机验收。

### 验证、素材与维护

这是候选版，不宣称所有特例或多人已验证。保留开发期的受控引擎 fixture 和原生配方测试；新的可移植检查入口见 [验证说明](docs/TESTING.md)。离线 Kahlua、模拟物品和原生解析不等于游戏内转移、贴布换外观、界面与保存重进验收。

运行文件与源安装包不变。只迁移自制验证源和工具，未包含个人存档、备份、部署/回滚脚本、游戏 stdlib 或上游模组源码。人物样图及图标是本项目 AI 辅助素材，宣传图不添加人物皮肤。原装备及兼容对象的权利归各作者；未擅自指定统一开源许可。详见 [来源与素材](docs/SOURCES.md)。

## English

An independent, one-time backpack capacity doubling add-on. Mod ID `ExSuQingBackpackSuperUpgrade_4221`, version, items and recipes are preserved. The `mods/` files match the current development/installable source byte for byte. This is separate from [ordinary Container Upgrades](https://github.com/suching8848/suqing-container-upgrade); they can coexist and be restored independently, and the ordinary mod is not a hard requirement.

### Check the main mod and its companion patches together

The base package directly supports 11 IDs: ten Legendary Backpack color variants and `Base.ResidentEvilBackPack`. Install the original `LBB42` or `RaccoonCityB42` equipment mod separately; neither is bundled. The Raccoon City suspenders, crates and vehicle storage are outside this base scope.

The author's current combinations also use [SuQing’s Project Zomboid Patches](https://github.com/suching8848/suqing-project-zomboid-patches). **These independent compatibility layers are not bundled with the main mod. Install the listed patches when using their matching combinations; downloading this repository alone does not provide every extension.**

| Combination | Companion patch Mod ID | Purpose and limits |
| --- | --- | --- |
| Nekomata Ridge capacity wrapper chain | `CodexNekomataEXCompat_4221` | Preserves the upstream calculation and connects the audited EX wrapper chain; unknown chains are refused |
| EX upgrades for the MaoMao backpack | `CodexNekomataEXUpgrade_4221`, plus the compatibility patch above | Separate extension recipe, from native business base 120 to EX 240; it is not a twelfth base-package item |
| HavenFall large backpacks and the current added wearable-container combination | `Codex_SuQingWearableCompat_4221` | Separately connects twenty base/T1/T2/T3 HavenFall backpack IDs; this patch currently also requires ordinary Container Upgrades and HavenFall |

Select patches for the actual combination; do not enable the whole collection indiscriminately. Their own `require`, version guards and load order still apply. Restore EX before a native HavenFall tier upgrade so that replacing the item does not lose its paid entitlement; that rule is implemented by the separate patch.

### Installation and use

1. Exit the game normally and retain a recovery option for current progress.
2. Copy `mods/ExSuQingBackpackSuperUpgrade_4221` into your user's `Zomboid/mods`, preserving `42` and `common`. The repository root is not the installable mod directory.
3. Enable this Mod ID in the target single-player save, respecting the original equipment and selected patches' `loadModAfter`. Keep one installation source for the ID.
4. Unequip the backpack, place it in main inventory, empty all items and fluids, and use the “蘇清·超级升级” crafting category.

One upgrade requires Tailoring 5, a kept needle, 40 clean ripped sheets, 20 leather strips, 20 normal thread uses and 4 premium fishing line uses. A full normal spool has 20 uses; premium line has 4. Disable free crafting/material bypass when testing actual payment.

At upgrade time, native business base capacity B, before character traits, establishes one fixed target 2B. Later calculations take the larger of that saved target and the current native base, then apply traits. Default Legendary 49→98; a Raccoon sandbox base of 98 gives 98→196. Reloading, changing appearance or changing sandbox values does not repeatedly double it.

Only ordinary-item business capacity is overlaid. Item weight, weight reduction, fluid liters, appearance, condition, attachments and storage filters remain. Ground-square, character and parent-container limits still apply; the native physical-capacity tooltip may differ from usable capacity.

### Restoration, saves and disabling

Empty and unequip the bag, then use the restore recipe. A fully paid upgrade refunds 50%: 20 sheets, 10 leather, 10 normal thread uses and 2 premium line uses. Free crafting earns no refund. Successful restoration clears only EX's own state/ledger and cannot refund twice; ordinary upgrades have a separate ledger.

After saving and exiting normally, disabling removes the EX capacity effect while retaining its record. Re-enabling restores that same upgrade without further payment or doubling. Disabling is not restoration and grants no automatic refund; empty the bag first. Overfilled-bag transfers, display and save/reload behavior after disabling still require in-game acceptance.

### Validation, assets and maintenance

This is a release candidate, without a claim of full edge-case or multiplayer validation. Controlled engine fixtures and native recipe tests from development are retained; see [Testing](docs/TESTING.md) for the portable entry point. Offline Kahlua, mock items and native parsing do not replace in-game transfer, patch/appearance conversion, UI and save/reload checks.

Runtime files are preserved. Only authored validation sources and useful tools were migrated; no personal saves, backups, deployment/rollback scripts, game stdlib or upstream mod source is included. The character sample and icons are AI-assisted project assets; promotional artwork does not add a character skin. Original equipment and compatibility targets belong to their authors; no blanket open-source license has been assigned. See [Sources and assets](docs/SOURCES.md).

## 相关项目与配置快照

[全部 8 个模组与补丁仓库](docs/project-index.md) · [当前单人档 205 项启用顺序](docs/current-single-player-modlist.md) · [作者 Steam 合集](https://steamcommunity.com/sharedfiles/filedetails/?id=3823981387)

源码索引涵盖 37 个 Mod ID。Steam 合集不附带独立本地补丁；按各项目的前置和条件兼容说明选择子项。启用快照不代表每个项目或新增版本均已通过游戏内验收。

## Related projects and setup snapshot

[All eight mod and patch repositories](docs/project-index.md) · [Current 205-ID enabled order](docs/current-single-player-modlist.md) · [Author’s Steam collection](https://steamcommunity.com/sharedfiles/filedetails/?id=3823981387)

The source index covers 37 Mod IDs. The Steam collection does not include separately installed local patches; select entries using each project’s requirements and conditional integration notes. Enabled state does not establish in-game acceptance of every project or new version.
