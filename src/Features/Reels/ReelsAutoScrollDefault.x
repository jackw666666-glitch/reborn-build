#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import "ReelsAutoScrollDefault.h"
#import <objc/runtime.h>

// Puts the reels auto scroll toggle into a chosen state once per controller, so it
// starts on or off every launch while the in-reels toggle keeps working for the
// rest of the session. Re-applies when the setting itself changes.

static const void *kSPKAutoScrollAppliedModeKey = &kSPKAutoScrollAppliedModeKey;

NSString *SPKReelsAutoScrollEffectiveMode(void) {
    if ([SPKUtils getBoolPref:@"reels_disable_scrolling"])
        return @"off";
    return [SPKUtils getStringPref:@"reels_auto_scroll_default"] ?: @"default";
}

static __weak id sJackAutoScrollController = nil;

static void SPKApplyReelsAutoScrollDefault(id controller) {
    if (!controller)
        return;
    sJackAutoScrollController = controller;

    NSString *mode = SPKReelsAutoScrollEffectiveMode();
    BOOL enable;
    if ([mode isEqualToString:@"on"]) {
        enable = YES;
    } else if ([mode isEqualToString:@"off"]) {
        enable = NO;
    } else {
        return;
    }

    NSString *applied = objc_getAssociatedObject(controller, kSPKAutoScrollAppliedModeKey);
    if ([applied isEqualToString:mode])
        return;
    objc_setAssociatedObject(controller, kSPKAutoScrollAppliedModeKey, mode, OBJC_ASSOCIATION_COPY_NONATOMIC);

    if ([controller respondsToSelector:@selector(setUserEnabled:)]) {
        [controller setUserEnabled:enable];
    } else if ([controller respondsToSelector:@selector(setIsEnabled:)]) {
        [controller setIsEnabled:enable];
    } else {
        SPKLog(@"Reels", @"Auto scroll controller has no known setter");
        return;
    }
    SPKLog(@"Reels", @"Auto scroll default applied: %@", mode);
}

%group SPKReelsAutoScrollDefaultHooks

%hook _TtC19IGSundialAutoScroll19IGSundialAutoScroll
- (id)initWith:(id)userDefaults launcherSet:(id)launcherSet {
    id result = %orig;
    SPKApplyReelsAutoScrollDefault(result);
    return result;
}
%end

%hook IGUserSession
- (id)autoScrollController {
    id controller = %orig;
    SPKApplyReelsAutoScrollDefault(controller);
    return controller;
}
%end

%end

void SPKInstallReelsAutoScrollDefaultHooksIfEnabled(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class autoScrollClass = objc_getClass("_TtC19IGSundialAutoScroll19IGSundialAutoScroll");
        if (!autoScrollClass) {
            SPKLog(@"Reels", @"Auto scroll controller class missing");
            return;
        }
        %init(SPKReelsAutoScrollDefaultHooks, _TtC19IGSundialAutoScroll19IGSundialAutoScroll = autoScrollClass);
    });
}

// Jack build: the full-screen reels "auto next" button flips Instagram's own auto scroll.
id JackReelsAutoScrollController(void) {
    return sJackAutoScrollController;
}

BOOL JackReelsAutoScrollOn(void) {
    id c = sJackAutoScrollController;
    return [c respondsToSelector:@selector(isEnabled)] && [c isEnabled];
}
