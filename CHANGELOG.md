# 更新记录 / Changelog

## 2026-11-02 源码整理 / Source migration

- 保留 1.0.0-rc.2 安装包的全部 26 个文件及其原 Mod ID、运行逻辑、配方、翻译、资源和版本。
- 添加完整中英使用说明、主模组与独立补丁对应关系、来源说明、可移植打包与验证入口。未执行安装、配置迁移或公开工坊发布。
- Preserves all 26 files of the 1.0.0-rc.2 installable package, including Mod ID, runtime logic, recipes, translations, assets and version.
- Adds complete Chinese/English usage, companion-patch mapping, provenance and portable package/validation entry points. No installation, configuration migration or public Workshop upload was performed.

## 离线检查 / Offline checks

EX core: 28 cases / 162 assertions; crafting transactions: 25 cases / 1520 assertions; native recipe parser: 32 assertions.

本次没有启动游戏，离线通过不等于完整游戏验收。 / The game was not launched; offline success does not establish full in-game acceptance.
