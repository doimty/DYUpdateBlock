# DYUpdateBlock

屏蔽抖音启动时强制更新弹窗的独立插件，默认生效，无设置项，装上即用。

## 原理

抖音启动时的强制更新由 `AWEMR*` 流程控制（40.9.0 `AwemeCore` 反汇编验证）。
`+[AWEMRLaunchForceUpdateManager judgeResultWithNeedBlock:reason:]`
是整个判断的唯一漏斗：配置、crash guard、版本/时间/频率比较的每条返回
路径都经过它。把它强制返回 `needBlock=NO` 后，启动不再被拦截，弹窗
也不会出现。

备用：`-[AWEMRForceUpdateViewController showForceUpdateDialog]` 直接 no-op，
即使判断逻辑在新版本变化，弹窗也弹不出来。

两个类都用运行时查名 + nil 保护：如果抖音版本里类名变了，插件静默不生效，不会崩。

## 触发原因

判断里只有版本/时间/频率比较，没有渠道、越狱、侧载或签名检测——
“经非官方渠道下载”只是弹窗文案。触发几乎可以确定是当前抖音版本
<= 服务端下发的 `maxAppVersion`。

## 构建

GitHub Actions（macos-26 + Theos），推到 `main` 即编出 rootful /
rootless / roothide 三个包 + dylib。
