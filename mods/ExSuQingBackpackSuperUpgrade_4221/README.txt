蘇清的背包超级升级 1.0.0-rc.3
B42.21–42.22 单人候选 / Single-player candidate

这是独立模组，ID：ExSuQingBackpackSuperUpgrade_4221。
不依赖普通“蘇清的容器升级”，可以单独开关、与普通版共存。
安装状态以安装回执为准。安装仅新增本模组目录并追加启用ID，不替换普通版或工坊原件。
初次安装不批量改写世界物品，实际升级由你在制作菜单中操作。

【适配范围】
传奇背包 10 款、行李袋 20 个位置／颜色变体、腰包 22 个位置／颜色变体、挎包 11 款和开封刀箱 3 款，共 66 个 ID。每个物品需要它所属的装备模组。封装刀箱仍按原配方开封。
已有非传奇 EX 记录仍可生效和还原。猫猫背包和 HavenFall 需要匹配 rc.3 的兼容补丁。

【升级】
制作菜单“蘇清·超级升级”分类，使用“传奇容器超级升级（原生基础容量×2）”配方。
卸下容器、不要拿在手上、放在人物主物品栏，清空内部物品和所有液体。
需要裁缝5级、针、40干净碎布、20皮革条、20普通线用量、4高级鱼线用量。
针保留；一满卷普通线20用量，一满卷高级鱼线4用量。
Debug仅用于生成物品和设技能；真实扣料测试必须关闭免费制作、材料绕过和即时动作。

容量以升级当时未计角色特性的原生业务基础值B为准，保存一次超级强化目标2B。
每类传奇容器读取其原模组的沙盒容量，例如基础 49 对应目标 98。
之后基础容量保留“固定超级强化目标”和“当前原生基础值”的较大者，再计角色特性。
已有原调用链更高的实际容量继续保留，角色特性不重复计算。
井井有条示例：98基础对应128有效容量，196基础对应255有效容量。
不能在同一件包上重复超级强化；重进、改外观、改沙盒不再次乘2。
如果现有无超级强化容量已经不低于目标，会拒绝没有容量收益的收费操作。

超级强化只增加普通物品收纳总容量。自重、减重、储水升数、耐久、外观、挂点和原功能保留。
原生地面方格50重量、人物承载、父车厢容量及原有收纳限制继续有效。
超50容量验收请穿戴或携带背包，通过正常物品转移验证；地面限制单独检查。
提示中的“超级升级实际可用容量”和穿戴后的容器栏应一致。原生物理容量行仍是参考值。

【还原与开关】
清空卸下后使用“蘇清：解除超级升级并返还实付材料的50％”，只清超级升级自己的状态和账本。
真实付过完整材料时返20碎布、10皮革、10普通线用量、2高级鱼线用量。
线按用量返，不是一整卷；免费制作没有真实付款，不产生返料。
重复还原不重复返料；失败会尝试恢复原材料实例、用量和超级强化状态，异常写日志。
普通强化与超级强化有各自独立账本，已有普通升级的传奇容器先还原普通升级。

正常保存退出游戏后停用本模组，再启动时超级强化容量效果消失，物理容量没有被超级强化永久写大。
超级强化记录仍保留在原物品上，重新启用后恢复同一次超级强化，不再扣料或连续翻倍。
停用不是还原，不自动返料。建议先清空超级强化包再停用。
满载停用后超载内容的保留、转出与容量显示仍须客户端验收，不承诺自动整理或丢地。
想彻底清除某件包的超级强化记录，请先在启用状态下使用撤销配方，再停用模组。

【传奇外观兼容】
原模组“缝上／拆下布章”会生成新背包，本模组为有效超级强化件保留该动作的内容与记录。
行李袋高低背和腰包前后位置变化也会转移原来物品的内容和超级升级记录。
普通未超级强化件继续使用原动作。完成转换后，付款权益归转换后的容器。
若动作发生外部API错误，恢复尝试与结果写入日志；未完成实机验证的范围请看测试清单。

【验证范围】
附带离线Lua/Kahlua、原生API签名及静态资源检查记录。
离线使用实际游戏Kahlua解释器和模拟对象，不等同于运行完整游戏。
安装不自动启动游戏或执行物品升级；客户端真实装入、保存重进、贴布和开关测试由用户完成。
多人及联机未验证。

English
Install the original Legendary equipment mods for the 66 supported IDs. The crafting recipe doubles the native base capacity once for Legendary backpacks, duffels, waist packs, satchels and opened weapon cases. Use the original recipes to open sealed cases.

Empty and unequip the container and place it in main inventory. The recipe requires Tailoring 5, a kept needle, 40 clean ripped sheets, 20 leather strips, 20 thread uses and 4 premium fishing line uses. Restoration returns 50% of the actual payment. Position changes and Legendary Backpack patch changes preserve the record and contents.

Existing non-Legendary records remain effective and restorable. MaoMao and HavenFall records require the matching rc.3 compatibility patches. The game itself still needs single-player acceptance testing.
