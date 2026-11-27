# DYUpdateBlock

屏蔽抖音所有更新弹窗的独立插件，默认生效，无设置项，装上即用。

## 原理

抖音有 8 条能弹出更新/拦截启动的路径，只拦一条不够（SJJ 的做法只拦
版本检查那条，所以很多人还看到弹窗）。本插件把 8 条里能用 ObjC hook
的全拦了（40.9.0 `AwemeCore` 反汇编验证）：

1. **启动强制更新（AWEMR）**：`+[AWEMRLaunchForceUpdateManager judgeResultWithNeedBlock:reason:]`
   强制返回 `needBlock=NO`（判断的唯一漏斗），备用
   `-[AWEMRForceUpdateViewController showForceUpdateDialog]` no-op。
   注意：AWEMR 判断里没有渠道/签名检测，只有版本/时间/频率比较；
   但另外两条路径有 bundle 路径检测（`checkEncryption`），由服务端开关
   控制，所以也拦。
2. **版本检查提示（AWENewVersionAlertManager）**：`check*` 方法全 no-op，
   备用 `showAlertViewWithInfo:confirmAction:cancelAction:` no-op；
   上游 `AWECheckVersionTask` / `AWEDYVersionManagerModuleService` 也拦。
3. **MessageReach 更新提示（AWEVersionUpdateAlert）**：`canShow` → NO，
   `showDialog` no-op，延迟触发 no-op。
4. **MR 通用强制弹窗（AWEVersionUpdateForcePopup）**：只在 eventID 匹配时拦，
   不匹配时放行（fail open），避免误拦账号/合规类强制弹窗。
5. **账号升级面板（AWEAccountForceUpgradeManager）**：gate → NO。
6. **青少年模式更新提示（AWETeenVersionUpdateManager）**：`canShow` → NO。
7. **App Store 打开（AWEVersionUpdateManager / AWEVersionUpdateWorkflow）**：
   工作流 no-op（仅当弹窗被拦不住时的兜底）。
8. **KMP 强制更新**：没有 ObjC 方法可 hook；若它走原生路径，上面已覆盖。

两个类都用运行时查名 + nil 保护：如果抖音版本里类名变了，插件静默不生效，不会崩。

## 触发原因

判断里只有版本/时间/频率比较，没有渠道、越狱、侧载或签名检测——
“经非官方渠道下载”只是弹窗文案。触发几乎可以确定是当前抖音版本
<= 服务端下发的 `maxAppVersion`。但另外两条路径（`AWEVersionUpdateAlert` /
`AWETeenVersionUpdateManager`）确实有 bundle 路径检测，由服务端开关
`forceUpgradeCheckEncryptionEnable` 控制。

## 构建

GitHub Actions（macos-26 + Theos），推到 `main` 即编出 rootful /
rootless / roothide 三个包 + dylib。
