# 验证说明 / Testing

中文：无需游戏即可执行 `python tools/validate.py`，核对完整安装包 SHA-256、Mod ID、版本和 JSON。`docs/runtime-sha256.json` 使用仓库相对路径，记录迁移时保留的原始包内容；需要有意维护版本时再更新该清单。

若拥有 Build 42.21 安装和 JDK，可执行 `python tools/validate.py --game-dir <game-directory> --javac <javac-command>`。`--java` 可指定匹配游戏版本的 Java。检查在系统临时目录编译自制 Java 检查器，从使用者安装读取 JAR 和 stdlib；不启动游戏、不安装模组、不写存档或启用列表。它编译全部运行 Lua，并执行自制模拟引擎 fixture 与原生配方解析。EX 仓库默认重跑核心容量/付款事务；Auto 默认重跑自动识别/付款事务。保留的转换/共存扩展用例另需对应原版和上游源码，默认入口不宣称覆盖那些额外集成。

使用 `python tools/package_mod.py --output <new-archive.zip>` 生成安装包；已存在的输出会拒绝覆盖。工具不会连接 Steam 或自动部署。游戏内仍需在隔离单人测试环境验收显示、转移、真实扣料、还原、保存重进及对应补丁组合；多人未验证。

English: Run `python tools/validate.py` without a game installation to check the complete installable package's SHA-256 values, Mod ID, version and JSON. `docs/runtime-sha256.json` uses repository-relative paths and records the source package preserved during migration; update it only as part of an intentional source/version change.

With Build 42.21 and a JDK, run `python tools/validate.py --game-dir <game-directory> --javac <javac-command>`. `--java` can select Java matching the game. Authored Java helpers compile in the system temporary directory and read the user's installed JAR/stdlib. The tool does not launch the game, install mods or write saves/enabled lists. It compiles every runtime Lua module and runs controlled engine fixtures plus the native recipe parser. The EX default covers core capacity/payment transactions; Auto covers automatic recognition/payment transactions. Included conversion/coexistence extension suites additionally need the matching ordinary/upstream sources and are not claimed as part of the default integration coverage.

Use `python tools/package_mod.py --output <new-archive.zip>` to create an installable archive. Existing output is not overwritten. No tool contacts Steam or deploys automatically. In-game display, transfers, actual payment, restoration, save/reload and matching companion-patch combinations still require an isolated single-player acceptance test. Multiplayer is untested.
