// DYUpdateBlock — 屏蔽抖音启动时强制更新弹窗，默认生效，无设置项。
//
// Hook 点（40.9.0 AwemeCore 反汇编验证）：
//   +[AWEMRLaunchForceUpdateManager judgeResultWithNeedBlock:reason:]
//   是整个强制更新判断的唯一漏斗：配置读取、crash guard、版本/时间/频率
//   比较的每条返回路径都经过它。强制返回 needBlock=NO 后，启动不再被
//   拦截，弹窗也不会出现。
// 备用：-[AWEMRForceUpdateViewController showForceUpdateDialog] 直接 no-op，
//   即使判断逻辑在新版本变化，弹窗也弹不出来。
//
// 触发原因说明：判断里只有版本/时间/频率比较，没有渠道、越狱、侧载或
// 签名检测——“经非官方渠道下载”只是弹窗文案。触发几乎可以确定是当前
// 抖音版本 <= 服务端下发的 maxAppVersion。
//
// 两个类都用运行时查名 + nil 保护：如果她抖音版本里类名变了，插件静默
// 不生效，不会崩。

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

%group DYUpdateBlockJudge
%hook AWEMRLaunchForceUpdateManager
+ (id)judgeResultWithNeedBlock:(BOOL)needBlock reason:(NSString *)reason {
    return %orig(NO, reason);
}
%end
%end

%group DYUpdateBlockDialog
%hook AWEMRForceUpdateViewController
- (void)showForceUpdateDialog {
}
%end
%end

%ctor {
    Class managerClass = objc_getClass("AWEMRLaunchForceUpdateManager");
    if (managerClass) {
        %init(DYUpdateBlockJudge, AWEMRLaunchForceUpdateManager = managerClass);
    }
    Class dialogClass = objc_getClass("AWEMRForceUpdateViewController");
    if (dialogClass) {
        %init(DYUpdateBlockDialog, AWEMRForceUpdateViewController = dialogClass);
    }
}
