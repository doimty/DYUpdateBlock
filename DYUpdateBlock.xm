// DYUpdateBlock — 屏蔽抖音所有更新弹窗，默认生效，无设置项。
//
// 40.9.0 AwemeCore 反汇编验证：抖音有 8 条能弹出更新/拦截启动的路径，只拦
// 一条不够（SJJ 的做法只拦版本检查那条，所以很多人还看到弹窗）。
// 本插件把 8 条里能用 ObjC hook 的全拦了：
//   1. 启动强制更新（AWEMR）：判断漏斗强制 NO + 弹窗 no-op。
//      注意：AWEMR 判断里没有渠道/签名检测，只有版本/时间/频率比较；
//      但另外两条路径（AWEVersionUpdateAlert / AWETeenVersionUpdateManager）
//      有 bundle 路径检测（checkEncryption），由服务端开关控制，所以也拦。
//   2. 版本检查提示（AWENewVersionAlertManager）：check* 全 no-op + 提示 no-op；
//      上游 AWECheckVersionTask / AWEDYVersionManagerModuleService 也拦。
//   3. MessageReach 更新提示（AWEVersionUpdateAlert）：canShow → NO +
//      showDialog no-op + 延迟触发 no-op。
//   4. MR 通用强制弹窗（AWEVersionUpdateForcePopup）：只在 eventID 匹配时拦，
//      不匹配时放行（fail open），避免误拦账号/合规类强制弹窗。
//   5. 账号升级面板（AWEAccountForceUpgradeManager）：gate → NO。
//   6. 青少年模式更新提示（AWETeenVersionUpdateManager）：canShow → NO。
//   7. App Store 打开（AWEVersionUpdateManager / AWEVersionUpdateWorkflow）：
//      工作流 no-op（仅当弹窗被拦不住时的兜底）。
//   8. KMP 强制更新：没有 ObjC 方法可 hook；若它走原生路径，上面已覆盖。
// 类名用运行时查名 + nil 保护：如果抖音版本里类名变了，静默不生效，不会崩。

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// Path 4 用：只拦版本更新强制弹窗，其他强制弹窗放行；任何环节缺失都放行。
static BOOL DYUpdateBlockShouldBlockForcePopup(id context) {
    if (!context || ![context respondsToSelector:@selector(eventID)]) {
        return NO;
    }
    NSString *eventID = [context eventID];
    if (!eventID) {
        return NO;
    }
    Class eventClass = NSClassFromString(@"AWEVersionUpdateForcePopupEvent");
    if (!eventClass || ![eventClass respondsToSelector:@selector(eventID)]) {
        return NO;
    }
    NSString *targetID = [eventClass eventID];
    return targetID && [eventID isEqualToString:targetID];
}

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

%group DYUpdateBlockNewVersionAlert
%hook AWENewVersionAlertManager
- (void)checkAppNewVersion {
}
- (void)checkAppNewVersionInhouse {
}
- (void)checkAppNewVersionInhouseWithDelay {
}
- (void)checkAppNewVersionTestFlight {
}
- (void)checkInhouseNewVersion {
}
- (void)checkInhouseNewVersionWithDelay {
}
- (void)showAlertViewWithInfo:(id)info confirmAction:(id)confirmAction cancelAction:(id)cancelAction {
}
%end
%end

%group DYUpdateBlockCheckVersionTask
%hook AWECheckVersionTask
+ (void)execute {
}
%end
%end

%group DYUpdateBlockVersionManagerService
%hook AWEDYVersionManagerModuleService
+ (void)checkAppNewVersion {
}
%end
%end

%group DYUpdateBlockVersionUpdateAlert
%hook AWEVersionUpdateAlert
- (BOOL)canShow {
    return NO;
}
- (void)showDialog {
}
+ (BOOL)delayTriggerVersionUpdateIfNeeded {
    return NO;
}
- (void)_showUpgradeModal {
}
- (void)showWithCloseCallback:(id)callback {
}
%end
%end

%group DYUpdateBlockVersionUpdatePopup
%hook AWEVersionUpdatePopup
- (void)showDialog {
}
- (void)showInfoPanel {
}
%end
%end

%group DYUpdateBlockForceNativeDialog
%hook AWEMRForceNativeDialogHandler
- (void)forceShowWithContext:(id)context callbackWrapper:(id)callbackWrapper {
    if (DYUpdateBlockShouldBlockForcePopup(context)) {
        return;
    }
    %orig;
}
%end
%end

%group DYUpdateBlockForceLynxDialog
%hook AWEMRForceLynxDialogHandler
- (void)forceShowWithContext:(id)context callbackWrapper:(id)callbackWrapper {
    if (DYUpdateBlockShouldBlockForcePopup(context)) {
        return;
    }
    %orig;
}
%end
%end

%group DYUpdateBlockAccountForceUpgrade
%hook AWEAccountForceUpgradeManager
+ (BOOL)shouldShowUpgradeAPPPanel {
    return NO;
}
- (void)showUpgradeAPPPanelWithMessage:(id)message completion:(id)completion {
}
%end
%end

%group DYUpdateBlockTeenVersionUpdate
%hook AWETeenVersionUpdateManager
- (BOOL)canShow {
    return NO;
}
- (void)p_showUpgradeAlert {
}
- (void)showWithCloseCallback:(id)callback {
}
%end
%end

%group DYUpdateBlockVersionUpdateWorkflow
%hook AWEVersionUpdateManager
- (void)startVersionUpdateWorkflow:(id)info completion:(id)completion {
}
%end
%end

%group DYUpdateBlockVersionUpdateWorkflow2
%hook AWEVersionUpdateWorkflow
- (void)startVersionUpdateWorkflow:(id)info completion:(id)completion {
}
%end
%end

%ctor {
    Class c;
    c = objc_getClass("AWEMRLaunchForceUpdateManager");
    if (c) { %init(DYUpdateBlockJudge, AWEMRLaunchForceUpdateManager = c); }
    c = objc_getClass("AWEMRForceUpdateViewController");
    if (c) { %init(DYUpdateBlockDialog, AWEMRForceUpdateViewController = c); }
    c = objc_getClass("AWENewVersionAlertManager");
    if (c) { %init(DYUpdateBlockNewVersionAlert, AWENewVersionAlertManager = c); }
    c = objc_getClass("AWECheckVersionTask");
    if (c) { %init(DYUpdateBlockCheckVersionTask, AWECheckVersionTask = c); }
    c = objc_getClass("AWEDYVersionManagerModuleService");
    if (c) { %init(DYUpdateBlockVersionManagerService, AWEDYVersionManagerModuleService = c); }
    c = objc_getClass("AWEVersionUpdateAlert");
    if (c) { %init(DYUpdateBlockVersionUpdateAlert, AWEVersionUpdateAlert = c); }
    c = objc_getClass("AWEVersionUpdatePopup");
    if (c) { %init(DYUpdateBlockVersionUpdatePopup, AWEVersionUpdatePopup = c); }
    c = objc_getClass("AWEMRForceNativeDialogHandler");
    if (c) { %init(DYUpdateBlockForceNativeDialog, AWEMRForceNativeDialogHandler = c); }
    c = objc_getClass("AWEMRForceLynxDialogHandler");
    if (c) { %init(DYUpdateBlockForceLynxDialog, AWEMRForceLynxDialogHandler = c); }
    c = objc_getClass("AWEAccountForceUpgradeManager");
    if (c) { %init(DYUpdateBlockAccountForceUpgrade, AWEAccountForceUpgradeManager = c); }
    c = objc_getClass("AWETeenVersionUpdateManager");
    if (c) { %init(DYUpdateBlockTeenVersionUpdate, AWETeenVersionUpdateManager = c); }
    c = objc_getClass("AWEVersionUpdateManager");
    if (c) { %init(DYUpdateBlockVersionUpdateWorkflow, AWEVersionUpdateManager = c); }
    c = objc_getClass("AWEVersionUpdateWorkflow");
    if (c) { %init(DYUpdateBlockVersionUpdateWorkflow2, AWEVersionUpdateWorkflow = c); }
}
