# 验证说明 / Testing

中文：无需游戏即可执行 `python tools/validate.py`，核对完整安装包 SHA-256、Mod ID、版本和 JSON。`docs/runtime-sha256.json` 使用仓库相对路径，记录迁移时保留的原始包内容；需要有意维护版本时再更新该清单。

若拥有 B42.21–42.22 安装和 JDK，可执行 `python tools/validate.py --game-dir <game-directory> --javac <javac-command>`。`--java` 可指定匹配游戏版本的 Java。检查在系统临时目录编译自制检查器并读取本机 JAR、stdlib 和原生换位 Lua。默认覆盖 Lua 编译、核心容量、付款、行李袋和腰包换位，以及原生配方解析。传奇背包贴布章和跨模组共存用例另需上游脚本。

使用 `python tools/package_mod.py --output <new-archive.zip>` 生成安装包；已存在的输出会拒绝覆盖。工具不会连接 Steam 或自动部署。游戏内仍需在隔离单人测试环境验收显示、转移、真实扣料、还原、保存重进及对应补丁组合；多人未验证。

English: Run `python tools/validate.py` without a game installation to check the complete installable package's SHA-256 values, Mod ID, version and JSON. `docs/runtime-sha256.json` uses repository-relative paths and records the source package preserved during migration; update it only as part of an intentional source/version change.

With B42.21–42.22 and a JDK, run `python tools/validate.py --game-dir <game-directory> --javac <javac-command>`. `--java` can select Java matching the game. The checker compiles its own test helpers in a temporary directory and reads the installed JAR, stdlib and vanilla wear action. It covers Lua compilation, core capacity, payment, duffel and waist-pack changes, and native recipe parsing. Tests for Legendary Backpack patches and coexistence also require the corresponding upstream Lua files.

Use `python tools/package_mod.py --output <new-archive.zip>` to create an installable archive. Existing output is not overwritten. No tool contacts Steam or deploys automatically. In-game display, transfers, actual payment, restoration, save/reload and matching companion-patch combinations still require an isolated single-player acceptance test. Multiplayer is untested.
