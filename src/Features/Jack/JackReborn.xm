// JACK BUILD ("Instagram Reborn"): the look-and-feel changes made for Jack.
//
//  - Feed header: Instagram's own wordmark stays, with "Reborn" in red, underlined, beside it.
//  - Feed header: the notifications heart is removed; it lives on your own profile instead.
//  - Tab bar: Instagram's own tab glyphs drawn in the Instagram gradient.
//  - App icon badge: set from Instagram's in-app unread counts (a re-signed copy gets no
//    Instagram pushes, so the badge is refreshed whenever the app runs or goes to the background).
//
// Every piece fails safe: if Instagram moves a view, that piece simply does nothing.

#import "../../Utils.h"
#import "../../AssetUtils.h"
#import "../../InstagramHeaders.h"
#import "../Profile/ProfileAnalyzer/SPKProfileAnalyzerViewController.h"
#import <UserNotifications/UserNotifications.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "../../Shared/Playback/SPKPlaybackPanel.h"

extern "C" SPKPlaybackTarget *JackReelsTargetForCell(UICollectionViewCell *cell);
static const NSInteger kJackReelsBarTag = 0x4A4342;

static const void *kJackRebornLabelKey = &kJackRebornLabelKey;
static const void *kJackGradientMarkKey = &kJackGradientMarkKey;
static const void *kJackHeartButtonKey = &kJackHeartButtonKey;
static const void *kJackHeartDotKey = &kJackHeartDotKey;

static UIColor *JackRebornRed(void) {
    return [UIColor colorWithRed:1.0 green:0.188 blue:0.251 alpha:1.0]; // Instagram's red, #FF3040
}

#pragma mark - Header helpers

static id JackGetter(id obj, NSString *name) {
    SEL sel = NSSelectorFromString(name);
    if (!obj || ![obj respondsToSelector:sel])
        return nil;
    return ((id (*)(id, SEL))objc_msgSend)(obj, sel);
}

static CGFloat JackCombinedAlpha(UIView *view, UIView *stopAt) {
    CGFloat alpha = 1.0;
    for (UIView *v = view; v && v != stopAt; v = v.superview) {
        if (v.hidden)
            return 0.0;
        alpha *= v.alpha;
    }
    return alpha;
}

// The wordmark: the widest image on the left side of the header (an image view, or a
// button's image view). Searched a few levels deep because Instagram wraps it.
static UIImageView *JackFindWordmark(UIView *root, UIView *header, int depth) {
    if (!root || depth > 5)
        return nil;
    for (UIView *sub in root.subviews) {
        if ([sub isKindOfClass:[UIImageView class]]) {
            UIImageView *iv = (UIImageView *)sub;
            CGSize s = iv.image.size;
            CGRect f = [iv convertRect:iv.bounds toView:header];
            if (!iv.hidden && s.height > 0 && s.width / s.height >= 2.2 && f.size.width >= 60 &&
                CGRectGetMidX(f) < header.bounds.size.width * 0.5)
                return iv;
        }
        UIImageView *found = JackFindWordmark(sub, header, depth + 1);
        if (found)
            return found;
    }
    return nil;
}

static UILabel *JackRebornLabel(UIView *header) {
    UILabel *label = objc_getAssociatedObject(header, kJackRebornLabelKey);
    if (label)
        return label;
    label = [UILabel new];
    label.userInteractionEnabled = NO;
    label.isAccessibilityElement = NO;
    label.backgroundColor = UIColor.clearColor;
    objc_setAssociatedObject(header, kJackRebornLabelKey, label, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [header addSubview:label];
    return label;
}

static void JackSetRebornText(UILabel *label, CGFloat height) {
    // Clean and small next to the script wordmark: semibold sans, thin underline.
    CGFloat size = MAX(12.0, round(height * 0.5));
    if (label.font && fabs(label.font.pointSize - size) < 0.5 && label.attributedText.length)
        return;
    UIFont *font = [UIFont systemFontOfSize:size weight:UIFontWeightSemibold];
    label.font = font;
    label.attributedText = [[NSAttributedString alloc] initWithString:@"Reborn" attributes:@{
        NSFontAttributeName : font,
        NSForegroundColorAttributeName : JackRebornRed(),
        NSKernAttributeName : @(0.3),
        NSUnderlineStyleAttributeName : @(NSUnderlineStyleSingle),
        NSUnderlineColorAttributeName : JackRebornRed(),
    }];
}

// Right edge of the wordmark group: the wordmark plus anything drawn just after it on the
// same line (the For you / Following arrow), so "Reborn" never covers it.
static CGFloat JackWordmarkGroupMaxX(UIImageView *logo, UIView *header, CGRect logoFrame, CGFloat drawnMaxX, UILabel *label) {
    CGFloat maxX = drawnMaxX;
    UIView *container = logo.superview;
    for (int up = 0; container && container != header && up < 2; up++, container = container.superview) {
        for (UIView *sib in container.subviews) {
            if (sib == logo || sib == label || sib.hidden || sib.alpha < 0.05)
                continue;
            if ([logo isDescendantOfView:sib])
                continue;
            CGRect f = [sib convertRect:sib.bounds toView:header];
            if (f.size.width > 60 || f.size.width < 2)
                continue;
            BOOL sameLine = CGRectGetMidY(f) > CGRectGetMinY(logoFrame) && CGRectGetMidY(f) < CGRectGetMaxY(logoFrame);
            BOOL justAfter = CGRectGetMinX(f) >= drawnMaxX - 4 && CGRectGetMinX(f) <= drawnMaxX + 30;
            if (sameLine && justAfter)
                maxX = MAX(maxX, CGRectGetMaxX(f));
        }
    }
    return maxX;
}

// Plus (create) button: hidden. Instagram's getter names first, then any small control left of the wordmark.
static void JackHideCreateButton(UIView *header, CGRect logoFrame) {
    for (NSString *key in @[ @"cameraButton", @"createButton", @"creationButton", @"newPostButton", @"plusButton", @"composeButton" ]) {
        id b = JackGetter(header, key);
        if ([b isKindOfClass:[UIView class]] && !((UIView *)b).hidden)
            ((UIView *)b).hidden = YES;
    }
    NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithObject:header];
    for (int n = 0; stack.count && n < 400; n++) {
        UIView *v = stack.lastObject;
        [stack removeLastObject];
        for (UIView *sub in v.subviews) {
            if ([sub isKindOfClass:[UIControl class]]) {
                CGRect f = [sub convertRect:sub.bounds toView:header];
                BOOL leftOfLogo = CGRectGetMaxX(f) <= CGRectGetMinX(logoFrame) + 2;
                BOOL small = f.size.width >= 16 && f.size.width <= 60 && f.size.height <= 60;
                BOOL sameLine = CGRectGetMidY(f) > CGRectGetMinY(logoFrame) - 10 && CGRectGetMidY(f) < CGRectGetMaxY(logoFrame) + 10;
                if (leftOfLogo && small && sameLine && !sub.hidden)
                    sub.hidden = YES;
                continue;
            }
            [stack addObject:sub];
        }
    }
}

// The For you / Following dropdown: its arrow is hidden and the wordmark no longer opens the menu.
static void JackDisableFeedPicker(UIImageView *logo, UIView *header, CGRect logoFrame, CGFloat drawnMaxX) {
    UIView *container = logo.superview;
    for (int up = 0; container && container != header && up < 2; up++, container = container.superview) {
        for (UIView *sib in container.subviews) {
            if (sib == logo || sib.hidden || [logo isDescendantOfView:sib] || [sib isKindOfClass:[UILabel class]])
                continue;
            CGRect f = [sib convertRect:sib.bounds toView:header];
            if (f.size.width > 40 || f.size.width < 2)
                continue;
            BOOL sameLine = CGRectGetMidY(f) > CGRectGetMinY(logoFrame) && CGRectGetMidY(f) < CGRectGetMaxY(logoFrame);
            BOOL justAfter = CGRectGetMinX(f) >= drawnMaxX - 4 && CGRectGetMinX(f) <= drawnMaxX + 30;
            if (sameLine && justAfter)
                sib.hidden = YES;
        }
    }
    CGFloat limit = header.bounds.size.width * 0.7;
    for (UIView *v = logo; v && v != header; v = v.superview) {
        if (v.bounds.size.width > limit)
            break;
        if ([v isKindOfClass:[UIControl class]] || v.gestureRecognizers.count) {
            if (v.userInteractionEnabled)
                v.userInteractionEnabled = NO;
        }
    }
}

static void JackLayoutFeedHeader(UIView *header) {
    // Heart: removed from the feed (it is on your own profile now).
    UIView *heart = JackGetter(header, @"activityButton");
    if ([heart isKindOfClass:[UIView class]] && !heart.hidden)
        heart.hidden = YES;

    // "Reborn" beside Instagram's wordmark.
    UIImageView *logo = JackFindWordmark(header, header, 0);
    UILabel *label = objc_getAssociatedObject(header, kJackRebornLabelKey);
    if (!logo) {
        label.hidden = YES;
        return;
    }
    label = JackRebornLabel(header);
    // Measure where Instagram put the wordmark, before our centering shift.
    if (!CGAffineTransformIsIdentity(logo.transform))
        logo.transform = CGAffineTransformIdentity;
    CGRect logoFrame = [logo convertRect:logo.bounds toView:header];
    // The image is aspect-fit inside its view: measure the drawn glyph, not the view.
    CGSize img = logo.image.size;
    CGFloat drawnW = logoFrame.size.width, drawnH = logoFrame.size.height;
    if (img.width > 0 && img.height > 0) {
        CGFloat scale = MIN(logoFrame.size.width / img.width, logoFrame.size.height / img.height);
        drawnW = img.width * scale;
        drawnH = img.height * scale;
    }
    CGFloat drawnMinX = CGRectGetMinX(logoFrame);
    if (logo.contentMode == UIViewContentModeScaleAspectFit || logo.contentMode == UIViewContentModeCenter)
        drawnMinX = CGRectGetMidX(logoFrame) - drawnW / 2.0;
    JackHideCreateButton(header, CGRectMake(drawnMinX, logoFrame.origin.y, drawnW, logoFrame.size.height));
    JackDisableFeedPicker(logo, header, logoFrame, drawnMinX + drawnW);
    JackSetRebornText(label, drawnH);
    [label sizeToFit];
    CGRect f = label.frame;
    CGFloat groupMaxX = JackWordmarkGroupMaxX(logo, header, logoFrame, drawnMinX + drawnW, label);
    // Center wordmark + "Reborn" as one group across the header.
    CGFloat gap = 8.0;
    CGFloat groupW = (groupMaxX - drawnMinX) + gap + f.size.width;
    CGFloat dx = round((header.bounds.size.width - groupW) / 2.0 - drawnMinX);
    CGFloat limit = header.bounds.size.width * 0.7;
    for (UIView *v = logo.superview; v && v != header && v.bounds.size.width <= limit; v = v.superview)
        if (v.clipsToBounds)
            v.clipsToBounds = NO;
    logo.transform = CGAffineTransformMakeTranslation(dx, 0);
    f.origin.x = round(groupMaxX + dx + gap);
    // Sit on the wordmark's baseline (the script's descenders hang below it).
    f.origin.y = round(CGRectGetMidY(logoFrame) + drawnH * 0.22 - f.size.height + label.font.descender * -1.0 - 1.0);
    if (!CGRectEqualToRect(label.frame, f))
        label.frame = f;
    label.alpha = JackCombinedAlpha(logo, header);
    label.hidden = NO;
    [header bringSubviewToFront:label];
}

%group JackFeedHeaderHooks

%hook IGHomeFeedHeaderView

- (void)layoutSubviews {
    %orig;
    if ([(UIView *)self window])
        JackLayoutFeedHeader((UIView *)self);
}

- (void)didMoveToWindow {
    %orig;
    if ([(UIView *)self window])
        [(UIView *)self setNeedsLayout];
}

%end

%end

#pragma mark - Badge counts

static __weak id JackLatestBadgeData;

static unsigned long long JackBadgeUnsigned(id data, NSString *key) {
    @try {
        id v = [data valueForKey:key];
        if ([v respondsToSelector:@selector(unsignedLongLongValue)])
            return [v unsignedLongLongValue];
    } @catch (__unused NSException *e) {
    }
    return 0;
}

static NSInteger JackActivityCount(void) {
    id data = JackLatestBadgeData;
    return data ? (NSInteger)JackBadgeUnsigned(data, @"activity") : 0;
}

static void JackRefreshHeartDots(void);

static void JackApplyAppBadge(void) {
    id data = JackLatestBadgeData;
    if (!data)
        return;
    unsigned long long total = JackBadgeUnsigned(data, @"totalCount");
    if (total == 0) {
        unsigned long long direct = 0;
        if ([data respondsToSelector:@selector(directMessagesServerCalculated)])
            direct = [(IGBadgeData *)data directMessagesServerCalculated];
        total = direct + JackBadgeUnsigned(data, @"activity");
    }
    NSInteger count = (NSInteger)MIN(total, 999ULL);
    if (@available(iOS 16.0, *)) {
        [[UNUserNotificationCenter currentNotificationCenter] setBadgeCount:count withCompletionHandler:nil];
    } else {
        [UIApplication sharedApplication].applicationIconBadgeNumber = count;
    }
}

static void JackScheduleBadgeRefresh(void) {
    static BOOL pending = NO;
    if (pending)
        return;
    pending = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        pending = NO;
        JackApplyAppBadge();
        JackRefreshHeartDots();
    });
}

%group JackBadgeHooks

%hook IGBadgeData

- (unsigned long long)directMessagesServerCalculated {
    unsigned long long r = %orig;
    if (JackLatestBadgeData != self) {
        JackLatestBadgeData = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            JackScheduleBadgeRefresh();
        });
    }
    return r;
}

%end

%end

#pragma mark - Heart on your own profile

static UIView *JackFindViewOfClass(UIView *root, Class cls) {
    if (!root || !cls)
        return nil;
    if ([root isKindOfClass:cls])
        return root;
    for (UIView *sub in root.subviews) {
        UIView *m = JackFindViewOfClass(sub, cls);
        if (m)
            return m;
    }
    return nil;
}

static void JackOpenActivityViaFeedHeart(void) {
    UIViewController *root = nil;
    for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]])
            continue;
        for (UIWindow *w in scene.windows)
            if (w.isKeyWindow)
                root = w.rootViewController;
    }
    Class tabCls = objc_getClass("IGTabBarController");
    UIViewController *tabs = nil;
    for (UIViewController *vc = root; vc && !tabs; vc = vc.childViewControllers.firstObject)
        if (tabCls && [vc isKindOfClass:tabCls])
            tabs = vc;
    SEL home = NSSelectorFromString(@"_timelineButtonPressed");
    if (tabs && [tabs respondsToSelector:home])
        ((void (*)(id, SEL))objc_msgSend)(tabs, home);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        Class headerCls = SPKResolveIGClass(@"IGHomeFeedHeader.IGHomeFeedHeaderView", @"IGHomeFeedHeaderView");
        UIView *header = JackFindViewOfClass(root.view, headerCls);
        UIControl *heart = JackGetter(header, @"activityButton");
        if ([heart isKindOfClass:[UIControl class]])
            [heart sendActionsForControlEvents:UIControlEventTouchUpInside];
        else
            SPKLog(@"Jack", @"Activity open fell through");
    });
}

static void JackOpenActivity(UIButton *sender) {
    // 1. Instagram's own router, pushed onto the profile tab.
    NSURL *url = [NSURL URLWithString:@"instagram://news"];
    Class handler = objc_getClass("IGURLHandler");
    SEL openSel = @selector(openInternalURL:presentationConfig:controller:animated:userSession:annotation:);
    if (handler && [handler respondsToSelector:openSel]) {
        typedef BOOL (*OpenFn)(Class, SEL, id, id, id, BOOL, id, id);
        if (((OpenFn)objc_msgSend)(handler, openSel, url, nil, topMostController(), YES, [SPKUtils activeUserSession], nil))
            return;
    }
    // 2. The app delegate's URL entry point.
    if ([SPKUtils openInstagramMediaURL:url dismissingPresentedViewControllers:NO])
        return;
    // 3. Last resort: go to Home and press the (hidden) feed heart, so Instagram navigates itself.
    JackOpenActivityViaFeedHeart();
}

static void JackRefreshHeartDot(UIButton *heart) {
    UIView *dot = objc_getAssociatedObject(heart, kJackHeartDotKey);
    if (!dot) {
        dot = [UIView new];
        dot.userInteractionEnabled = NO;
        dot.backgroundColor = JackRebornRed();
        dot.layer.cornerRadius = 4.0;
        dot.frame = CGRectMake(0, 0, 8, 8);
        objc_setAssociatedObject(heart, kJackHeartDotKey, dot, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [heart addSubview:dot];
    }
    CGRect b = heart.bounds;
    dot.center = CGPointMake(CGRectGetMidX(b) + 1.0, CGRectGetMaxY(b) - 4.0);
    dot.hidden = JackActivityCount() == 0;
}

static NSHashTable<UIButton *> *JackHeartButtons(void) {
    static NSHashTable *table;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        table = [NSHashTable weakObjectsHashTable];
    });
    return table;
}

static void JackRefreshHeartDots(void) {
    for (UIButton *heart in JackHeartButtons())
        JackRefreshHeartDot(heart);
}

@interface JackHeartButton : UIButton
@end

@implementation JackHeartButton
- (void)layoutSubviews {
    [super layoutSubviews];
    JackRefreshHeartDot(self);
}
- (void)jack_tapped {
    JackOpenActivity(self);
}
- (CGSize)intrinsicContentSize {
    return CGSizeMake(44, 44);
}
@end

extern "C" UIView *JackProfileHeartButton(UIView *header) {
    JackHeartButton *heart = objc_getAssociatedObject(header, kJackHeartButtonKey);
    if (heart)
        return heart;
    heart = [JackHeartButton buttonWithType:UIButtonTypeSystem];
    UIImage *glyph = [SPKAssetUtils instagramIconNamed:@"heart" pointSize:24.0 renderingMode:UIImageRenderingModeAlwaysTemplate];
    [heart setImage:glyph forState:UIControlStateNormal];
    heart.tintColor = UIColor.labelColor;
    heart.frame = CGRectMake(0, 0, 44, 44);
    heart.accessibilityLabel = @"Notifications";
    heart.accessibilityIdentifier = @"jack-profile-heart";
    [heart addTarget:heart action:@selector(jack_tapped) forControlEvents:UIControlEventTouchUpInside];
    objc_setAssociatedObject(header, kJackHeartButtonKey, heart, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [JackHeartButtons() addObject:heart];
    return heart;
}

// Followers button on your own profile: opens the follower analysis (who doesn't follow
// you back, who unfollowed you and when). Opening it makes no calls; only Scan does.
static const void *kJackFollowersButtonKey = &kJackFollowersButtonKey;

@interface JackFollowersButton : UIButton
@end

@implementation JackFollowersButton
- (void)jack_tapped {
    [SPKProfileAnalyzerViewController presentFromTop];
}
- (CGSize)intrinsicContentSize {
    return CGSizeMake(44, 44);
}
@end

extern "C" UIView *JackProfileFollowersButton(UIView *header) {
    JackFollowersButton *button = objc_getAssociatedObject(header, kJackFollowersButtonKey);
    if (button)
        return button;
    button = [JackFollowersButton buttonWithType:UIButtonTypeSystem];
    UIImage *glyph = [SPKAssetUtils instagramIconNamed:@"users" pointSize:24.0 renderingMode:UIImageRenderingModeAlwaysTemplate];
    if (!glyph)
        glyph = [UIImage systemImageNamed:@"person.2"];
    [button setImage:glyph forState:UIControlStateNormal];
    button.tintColor = UIColor.labelColor;
    button.frame = CGRectMake(0, 0, 44, 44);
    button.accessibilityLabel = @"Followers";
    button.accessibilityIdentifier = @"jack-profile-followers";
    [button addTarget:button action:@selector(jack_tapped) forControlEvents:UIControlEventTouchUpInside];
    objc_setAssociatedObject(header, kJackFollowersButtonKey, button, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return button;
}

// Instagram 435 builds the profile top bar from Swift, so the array hook never sees it.
// The followers button and heart are placed by hand, just left of the right-hand menu button.
static UIViewController *JackOwningViewController(UIView *v) {
    for (UIResponder *r = v; r; r = r.nextResponder)
        if ([r isKindOfClass:[UIViewController class]])
            return (UIViewController *)r;
    return nil;
}

extern "C" BOOL JackHeaderIsTabRoot(UIView *header) {
    UIViewController *vc = JackOwningViewController(header);
    for (UIViewController *c = vc; c; c = c.parentViewController) {
        UINavigationController *nav = c.navigationController;
        if (nav)
            return nav.viewControllers.firstObject == c || (nav.viewControllers.count == 1);
    }
    return NO;
}

extern "C" void JackPlaceProfileButtons(UIView *header, BOOL ownProfile) {
    UIView *followers = JackProfileFollowersButton(header);
    UIView *heart = JackProfileHeartButton(header);
    if (!ownProfile) {
        followers.hidden = YES;
        heart.hidden = YES;
        return;
    }
    CGFloat w = header.bounds.size.width;
    if (w < 200)
        return;
    // Rightmost native control in the right part of the bar (the menu button).
    UIView *anchor = nil;
    CGRect anchorFrame = CGRectNull;
    NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithObject:header];
    for (int n = 0; stack.count && n < 300; n++) {
        UIView *v = stack.lastObject;
        [stack removeLastObject];
        for (UIView *sub in v.subviews) {
            if (sub == followers || sub == heart || sub.hidden)
                continue;
            if ([sub isKindOfClass:[UIControl class]]) {
                CGRect f = [sub convertRect:sub.bounds toView:header];
                if (f.size.width >= 16 && f.size.width <= 64 && f.size.height <= 64 && CGRectGetMinX(f) > w * 0.6 &&
                    (CGRectIsNull(anchorFrame) || CGRectGetMinX(f) < CGRectGetMinX(anchorFrame))) {
                    anchor = sub;
                    anchorFrame = f;
                }
                continue;
            }
            [stack addObject:sub];
        }
    }
    CGFloat side = 40.0;
    CGFloat rightX = anchor ? CGRectGetMinX(anchorFrame) - 4.0 : w - 56.0;
    CGFloat midY = anchor ? CGRectGetMidY(anchorFrame) : header.bounds.size.height - 26.0;
    CGFloat alpha = anchor ? JackCombinedAlpha(anchor, header) : 1.0;
    NSArray<UIView *> *order = @[ heart, followers ]; // right to left
    for (NSUInteger i = 0; i < order.count; i++) {
        UIView *b = order[i];
        if (b.superview != header)
            [header addSubview:b];
        CGRect f = CGRectMake(round(rightX - side * (i + 1)), round(midY - side / 2.0), side, side);
        if (!CGRectEqualToRect(b.frame, f))
            b.frame = f;
        b.hidden = NO;
        b.alpha = alpha;
        [header bringSubviewToFront:b];
    }
}

#pragma mark - Gradient tab icons

static UIImage *JackGradientImage(UIImage *source) {
    if (!source || source.size.width <= 0 || source.size.height <= 0)
        return nil;
    static NSMapTable<UIImage *, UIImage *> *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cache = [NSMapTable weakToStrongObjectsMapTable];
    });
    UIImage *cached = [cache objectForKey:source];
    if (cached)
        return cached;

    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.scale = source.scale;
    format.opaque = NO;
    CGRect r = (CGRect){CGPointZero, source.size};
    UIImage *out = [[[UIGraphicsImageRenderer alloc] initWithSize:source.size format:format]
        imageWithActions:^(UIGraphicsImageRendererContext *rc) {
            CGContextRef ctx = rc.CGContext;
            [[source imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] drawInRect:r];
            CGContextSetBlendMode(ctx, kCGBlendModeSourceIn);
            // Instagram's gradient, yellow bottom-left to purple top-right.
            CGFloat comps[] = {
                0.996, 0.855, 0.459, 1.0, // #FEDA75
                0.980, 0.494, 0.118, 1.0, // #FA7E1E
                0.839, 0.161, 0.463, 1.0, // #D62976
                0.588, 0.184, 0.749, 1.0, // #962FBF
                0.310, 0.357, 0.835, 1.0, // #4F5BD5
            };
            CGFloat locs[] = {0.0, 0.25, 0.5, 0.75, 1.0};
            CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
            CGGradientRef g = CGGradientCreateWithColorComponents(cs, comps, locs, 5);
            CGContextDrawLinearGradient(ctx, g, CGPointMake(0, r.size.height), CGPointMake(r.size.width, 0), 0);
            CGGradientRelease(g);
            CGColorSpaceRelease(cs);
        }];
    out = [out imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    objc_setAssociatedObject(out, kJackGradientMarkKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [cache setObject:out forKey:source];
    return out;
}

static BOOL JackIsProfileTab(UIButton *button) {
    NSString *ident = button.accessibilityIdentifier.lowercaseString ?: @"";
    return [ident containsString:@"profile"] || [ident containsString:@"avatar"];
}

static void JackApplyGradientToTabButton(UIButton *button) {
    if (![button isKindOfClass:[UIButton class]] || JackIsProfileTab(button))
        return;
    UIControlState states[] = {UIControlStateNormal, UIControlStateHighlighted, UIControlStateSelected,
                               UIControlStateSelected | UIControlStateHighlighted};
    for (int i = 0; i < 4; i++) {
        UIImage *img = [button imageForState:states[i]];
        if (!img || objc_getAssociatedObject(img, kJackGradientMarkKey))
            continue;
        // Only an image set explicitly for this state (not a fallback to Normal).
        if (i > 0 && img == [button imageForState:UIControlStateNormal])
            continue;
        UIImage *grad = JackGradientImage(img);
        if (grad && grad != img)
            [button setImage:grad forState:states[i]];
    }
}

%group JackTabBarHooks

%hook IGTabBarButton

- (void)layoutSubviews {
    %orig;
    JackApplyGradientToTabButton((UIButton *)self);
}

%end

%hook IGTabBarController

- (void)_layoutTabBar {
    %orig;
    id bar = [self respondsToSelector:@selector(tabBar)] ? [(IGTabBarController *)self tabBar] : nil;
    id buttons = JackGetter(bar, @"buttons");
    if ([buttons isKindOfClass:[NSArray class]])
        for (id b in (NSArray *)buttons)
            JackApplyGradientToTabButton(b);
}

%end

%end

#pragma mark - Meta One / Meta Verified upsell blocker

// The upsell is a server-built sheet with no stable class, so it is recognised by its words:
// whatever gets presented is read a few times as it loads, and closed if it is the upsell.
static BOOL JackTextIsMetaUpsell(NSString *t) {
    if (t.length == 0)
        return NO;
    NSString *l = t.lowercaseString;
    return [l containsString:@"meta one"] || [l containsString:@"meta verified"] || [l containsString:@"verified badge"];
}

static BOOL JackViewShowsMetaUpsell(UIView *v, int depth) {
    if (!v || depth > 40)
        return NO;
    if (JackTextIsMetaUpsell(v.accessibilityLabel))
        return YES;
    if ([v isKindOfClass:[UILabel class]] && (JackTextIsMetaUpsell(((UILabel *)v).text) || JackTextIsMetaUpsell(((UILabel *)v).attributedText.string)))
        return YES;
    if ([v isKindOfClass:[UITextView class]] && JackTextIsMetaUpsell(((UITextView *)v).text))
        return YES;
    for (UIView *sub in v.subviews)
        if (JackViewShowsMetaUpsell(sub, depth + 1))
            return YES;
    return NO;
}

static void JackCheckPresentedForUpsell(UIViewController *vc, int attempt) {
    if (!vc || attempt > 5)
        return;
    double delays[] = {0.15, 0.4, 0.8, 1.4, 2.2, 3.5};
    __weak UIViewController *weakVC = vc;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delays[attempt] * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIViewController *strong = weakVC;
        if (!strong || !strong.presentingViewController || strong.isBeingDismissed)
            return;
        if (strong.isViewLoaded && JackViewShowsMetaUpsell(strong.view, 0)) {
            SPKLog(@"Jack", @"Closed Meta upsell %@", NSStringFromClass([strong class]));
            [strong.presentingViewController dismissViewControllerAnimated:NO completion:nil];
            return;
        }
        JackCheckPresentedForUpsell(strong, attempt + 1);
    });
}

%group JackUpsellHooks

%hook UIViewController

- (void)presentViewController:(UIViewController *)vc animated:(BOOL)animated completion:(id)completion {
    %orig;
    JackCheckPresentedForUpsell(vc, 0);
}

%end

%end

#pragma mark - "Are you interested in this post?" prompt

// A feed bubble with no stable class, so it is recognised by its question. The highest small
// ancestor of that label (the bubble, arrow included) is hidden; nothing is tapped or sent.
static BOOL JackTextIsInterestPrompt(NSString *t) {
    if (t.length < 20 || t.length > 80)
        return NO;
    return [t rangeOfString:@"interested in this post" options:NSCaseInsensitiveSearch].location != NSNotFound;
}

static void JackHideInterestPrompt(UILabel *label) {
    __weak UILabel *weakLabel = label;
    dispatch_async(dispatch_get_main_queue(), ^{
        UILabel *l = weakLabel;
        if (!l || !l.window)
            return;
        UIView *target = nil;
        for (UIView *v = l.superview; v && ![v isKindOfClass:[UIWindow class]]; v = v.superview) {
            if ([v isKindOfClass:[UICollectionViewCell class]] || [v isKindOfClass:[UITableViewCell class]] || [v isKindOfClass:[UIScrollView class]])
                break;
            if (v.bounds.size.height > 0 && v.bounds.size.height <= 240)
                target = v;
            else if (target)
                break;
        }
        if (target) {
            target.hidden = YES;
            target.alpha = 0;
            SPKLog(@"Jack", @"Hid interest prompt %@", NSStringFromClass([target class]));
        }
    });
}

%group JackInterestPromptHooks

%hook UILabel

- (void)setText:(NSString *)text {
    %orig;
    if (JackTextIsInterestPrompt(text))
        JackHideInterestPrompt(self);
}

- (void)setAttributedText:(NSAttributedString *)text {
    %orig;
    if (JackTextIsInterestPrompt(text.string))
        JackHideInterestPrompt(self);
}

%end

%end

#pragma mark - Reels fade to full screen

// Reels play full screen: after a couple of seconds the buttons, caption and tab icons fade away and
// stay away while scrolling. First tap brings them back (and is swallowed, so it doesn't pause);
// a tap while they're showing pauses as normal. Blurs and gradients along the bottom are kept.
// Purely visual.
static const void *kJackReelsImmersiveKey = &kJackReelsImmersiveKey;
static const void *kJackSavedAlphaKey = &kJackSavedAlphaKey;

static BOOL JackViewIsVideo(UIView *v) {
    NSString *n = NSStringFromClass([v class]);
    return [n containsString:@"VideoPlaybackView"] || [n containsString:@"PlayerView"] || [n containsString:@"PlayerLayerView"] ||
           ([v isKindOfClass:[UIImageView class]] && v.bounds.size.height > 300);
}

// Background blur / gradient scrims stay; what sits on them still fades.
static BOOL JackViewIsBackdrop(UIView *v) {
    // Only full-width blurs/gradients (the bottom fade) are kept; small ones (avatar ring, button pills) fade.
    if (v.bounds.size.width < UIScreen.mainScreen.bounds.size.width * 0.85)
        return NO;
    if ([v isKindOfClass:[UIVisualEffectView class]] || [v.layer isKindOfClass:[CAGradientLayer class]])
        return YES;
    NSString *n = NSStringFromClass([v class]);
    return [n containsString:@"Gradient"] || [n containsString:@"Blur"] || [n containsString:@"Scrim"] || [n containsString:@"Backdrop"];
}

static BOOL JackContainsKeep(UIView *v, int depth) {
    if (JackViewIsVideo(v) || JackViewIsBackdrop(v) || [v isKindOfClass:[UICollectionView class]])
        return YES;
    if (depth > 7)
        return NO;
    for (UIView *sub in v.subviews)
        if (JackContainsKeep(sub, depth + 1))
            return YES;
    return NO;
}

static void JackCollectOverlays(UIView *v, NSMutableArray<UIView *> *out, int depth) {
    for (UIView *sub in v.subviews) {
        if (sub.hidden || sub.tag == kJackReelsBarTag)
            continue;
        if ([sub isKindOfClass:[UICollectionView class]]) {
            for (UICollectionViewCell *cell in ((UICollectionView *)sub).visibleCells)
                JackCollectOverlays(cell.contentView, out, depth + 1);
            continue;
        }
        if (JackViewIsVideo(sub))
            continue;
        if (JackViewIsBackdrop(sub)) {
            UIView *inner = [sub isKindOfClass:[UIVisualEffectView class]] ? ((UIVisualEffectView *)sub).contentView : sub;
            if (depth < 12)
                JackCollectOverlays(inner, out, depth + 1);
            continue;
        }
        if (depth < 12 && JackContainsKeep(sub, 0))
            JackCollectOverlays(sub, out, depth + 1);
        else
            [out addObject:sub];
    }
}

static BOOL gJackReelsFaded = NO; // read by the setAlpha guard below
static BOOL gJackOwnAlphaWrite = NO; // our own hiding writes must not overwrite the saved alpha

static void JackZeroAlpha(UIView *v) {
    gJackOwnAlphaWrite = YES;
    v.alpha = 0.0;
    gJackOwnAlphaWrite = NO;
}

@interface JackReelsImmersive : NSObject <UIGestureRecognizerDelegate>
@property (nonatomic, weak) UIViewController *controller;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) CFTimeInterval lastActivity;
@property (nonatomic, assign) BOOL faded;
@property (nonatomic, strong) NSHashTable<UIView *> *fadedViews;
@property (nonatomic, strong) UITapGestureRecognizer *tap;
@property (nonatomic, strong) UIView *bar;
@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) UIButton *skipButton;
@property (nonatomic, strong) UIButton *muteButton;
@end

@implementation JackReelsImmersive

- (UICollectionView *)collectionView {
    NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithObject:self.controller.view];
    for (int n = 0; stack.count && n < 200; n++) {
        UIView *v = stack.firstObject;
        [stack removeObjectAtIndex:0];
        if ([v isKindOfClass:[UICollectionView class]])
            return (UICollectionView *)v;
        [stack addObjectsFromArray:v.subviews];
    }
    return nil;
}

// MARK: Play / skip / mute buttons (shown only with the controls)

- (UIButton *)roundButton:(CGFloat)size action:(SEL)action {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = CGRectMake(0, 0, size, size);
    b.tintColor = UIColor.whiteColor;
    b.layer.cornerRadius = size / 2;
    b.clipsToBounds = YES;
    UIVisualEffectView *glass = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark]];
    glass.frame = b.bounds;
    glass.userInteractionEnabled = NO;
    [b insertSubview:glass atIndex:0];
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return b;
}

- (UIView *)buildBar {
    if (self.bar)
        return self.bar;
    CGFloat small = 52, big = 66, gap = 30;
    UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, small * 2 + big + gap * 2, big)];
    bar.tag = kJackReelsBarTag;
    bar.alpha = 0.0;
    self.muteButton = [self roundButton:small action:@selector(muteTapped)];
    self.playButton = [self roundButton:big action:@selector(playTapped)];
    self.skipButton = [self roundButton:small action:@selector(skipTapped)];
    self.muteButton.center = CGPointMake(small / 2, big / 2);
    self.playButton.center = CGPointMake(small + gap + big / 2, big / 2);
    self.skipButton.center = CGPointMake(bar.bounds.size.width - small / 2, big / 2);
    [bar addSubview:self.muteButton];
    [bar addSubview:self.playButton];
    [bar addSubview:self.skipButton];
    [self setSymbol:@"goforward.10" on:self.skipButton size:22];
    self.bar = bar;
    return bar;
}

- (void)setSymbol:(NSString *)name on:(UIButton *)b size:(CGFloat)pt {
    if ([objc_getAssociatedObject(b, @selector(setSymbol:on:size:)) isEqualToString:name])
        return;
    objc_setAssociatedObject(b, @selector(setSymbol:on:size:), name, OBJC_ASSOCIATION_COPY_NONATOMIC);
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:pt weight:UIImageSymbolWeightSemibold];
    [b setImage:[UIImage systemImageNamed:name withConfiguration:cfg] forState:UIControlStateNormal];
}

- (UICollectionViewCell *)currentCell {
    UICollectionView *cv = [self collectionView];
    Class videoCell = NSClassFromString(@"IGSundialViewerVideoCell");
    if (!cv || !videoCell)
        return nil;
    CGFloat mid = cv.contentOffset.y + cv.bounds.size.height / 2;
    UICollectionViewCell *best = nil;
    CGFloat bestDist = CGFLOAT_MAX;
    for (UICollectionViewCell *c in cv.visibleCells) {
        if (![c isKindOfClass:videoCell])
            continue;
        CGFloat d = fabs(CGRectGetMidY(c.frame) - mid);
        if (d < bestDist) {
            bestDist = d;
            best = c;
        }
    }
    return best;
}

static id JackAudioAnnouncer(void) {
    Class cls = NSClassFromString(@"IGAudioStatusAnnouncer");
    SEL shared = NSSelectorFromString(@"sharedInstance");
    return [cls respondsToSelector:shared] ? ((id (*)(id, SEL))objc_msgSend)(cls, shared) : nil;
}

static long long *JackStickySoundSlot(id announcer) {
    Ivar ivar = announcer ? class_getInstanceVariable([announcer class], "_stickySoundState") : NULL;
    return ivar ? (long long *)((uint8_t *)(__bridge void *)announcer + ivar_getOffset(ivar)) : NULL;
}

static BOOL JackReelsMuted(void) {
    long long *slot = JackStickySoundSlot(JackAudioAnnouncer());
    return !slot || *slot != 2; // 2 = user unmuted; unset starts muted (locked setting)
}

- (void)refreshBar {
    if (!self.bar)
        return;
    UIView *root = self.controller.view;
    if (self.bar.superview != root)
        [root addSubview:self.bar];
    else if (root.subviews.lastObject != self.bar)
        [root bringSubviewToFront:self.bar];
    self.bar.center = CGPointMake(CGRectGetMidX(root.bounds), CGRectGetMidY(root.bounds));
    UICollectionViewCell *cell = [self currentCell];
    BOOL playing = cell ? JackReelsTargetForCell(cell).isPlaying() : NO;
    [self setSymbol:(playing ? @"pause.fill" : @"play.fill") on:self.playButton size:28];
    [self setSymbol:(JackReelsMuted() ? @"speaker.slash.fill" : @"speaker.wave.2.fill") on:self.muteButton size:20];
}

- (void)playTapped {
    UICollectionViewCell *cell = [self currentCell];
    if (!cell)
        return;
    JackReelsTargetForCell(cell).togglePlayback();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self refreshBar];
    });
}

- (void)skipTapped {
    UICollectionViewCell *cell = [self currentCell];
    if (!cell)
        return;
    SPKPlaybackTarget *t = JackReelsTargetForCell(cell);
    double d = t.duration(), now = t.currentTime();
    if (d <= 1.0)
        return;
    BOOL wasPlaying = t.isPlaying();
    t.seek(MIN(now + 10.0, d - 0.3), ^{
        if (wasPlaying && !t.isPlaying() && t.resumeAfterSeek)
            t.resumeAfterSeek();
    });
}

- (void)muteTapped {
    id announcer = JackAudioAnnouncer();
    long long next = JackReelsMuted() ? 2 : 1;
    SEL setter = NSSelectorFromString(@"setStickySoundState:forReason:");
    if ([announcer respondsToSelector:setter]) {
        ((void (*)(id, SEL, long long, long long))objc_msgSend)(announcer, setter, next, 5);
    } else {
        long long *slot = JackStickySoundSlot(announcer);
        if (slot)
            *slot = next;
    }
    [self refreshBar];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)g shouldReceiveTouch:(UITouch *)touch {
    return !(self.bar && [touch.view isDescendantOfView:self.bar]);
}

- (void)start {
    if (!self.fadedViews)
        self.fadedViews = [NSHashTable weakObjectsHashTable];
    self.lastActivity = CACurrentMediaTime();
    if (!self.tap) {
        self.tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(revealTap)];
        self.tap.delegate = self;
        self.tap.cancelsTouchesInView = YES;
        [self.controller.view addGestureRecognizer:self.tap];
    }
    [self.timer invalidate];
    __weak typeof(self) weakSelf = self;
    self.timer = [NSTimer scheduledTimerWithTimeInterval:0.1 repeats:YES block:^(__unused NSTimer *t) {
        [weakSelf tick];
    }];
    [NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes]; // keep ticking while scrolling
    // Full screen from the start.
    [self fadeAnimated:NO];
}

- (void)enforce {
    if (self.faded)
        [self fadeAnimated:NO];
}

// A reel cell being loaded or laid out: hide its controls right now, before it is ever drawn.
- (void)fadeCell:(UICollectionViewCell *)cell {
    if (!self.faded)
        return;
    NSMutableArray<UIView *> *out = [NSMutableArray array];
    JackCollectOverlays(cell.contentView, out, 1);
    for (UIView *v in out) {
        if (![self.fadedViews containsObject:v]) {
            if (v.hidden)
                continue;
            if (!objc_getAssociatedObject(v, kJackSavedAlphaKey))
                objc_setAssociatedObject(v, kJackSavedAlphaKey, @(v.alpha), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [self.fadedViews addObject:v];
        }
        [v.layer removeAnimationForKey:@"opacity"];
        if (v.alpha > 0.0)
            JackZeroAlpha(v);
    }
}

- (void)stop {
    [self.timer invalidate];
    self.timer = nil;
    [self showAnimated:NO];
}

// Tap toggles the controls on/off (Instagram's own taps wait for it and lose); hold still pauses.
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)g {
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)g shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)other {
    return g == self.tap && [other isKindOfClass:[UITapGestureRecognizer class]];
}

- (void)revealTap {
    self.lastActivity = CACurrentMediaTime();
    if (self.faded)
        [self showAnimated:YES];
    else
        [self fadeAnimated:YES];
}

- (void)tick {
    UIViewController *vc = self.controller;
    if (!vc || !vc.viewIfLoaded.window) {
        [self stop];
        return;
    }
    // A sheet over the reel (comments, share) keeps everything visible.
    if (vc.presentedViewController) {
        self.lastActivity = CACurrentMediaTime();
        if (self.faded)
            [self showAnimated:YES];
        return;
    }
    if (!self.faded) {
        // Controls stay on (across swipes) until the next tap.
        [self buildBar];
        [self refreshBar];
        if (self.bar.alpha < 0.01)
            [UIView animateWithDuration:0.25 animations:^{ self.bar.alpha = 1.0; }];
    } else {
        // Stay full screen while scrolling: newly shown reels never show their controls.
        [self fadeAnimated:NO];
    }
}

- (UIView *)tabBarView {
    UIView *bar = self.controller.tabBarController.tabBar;
    if (bar)
        return bar;
    UIViewController *tbc = self.controller;
    while (tbc && ![NSStringFromClass([tbc class]) containsString:@"TabBarController"])
        tbc = tbc.parentViewController;
    id igBar = tbc ? JackGetter(tbc, @"tabBar") : nil;
    return [igBar isKindOfClass:[UIView class]] ? igBar : nil;
}

- (NSArray<UIView *> *)targets {
    NSMutableArray<UIView *> *out = [NSMutableArray array];
    if (self.controller.viewIfLoaded)
        JackCollectOverlays(self.controller.view, out, 0);
    UIView *bar = [self tabBarView];
    if (bar)
        [out addObject:bar];
    return out;
}

- (void)fadeAnimated:(BOOL)animated {
    if (self.bar.alpha > 0.0) {
        if (animated)
            [UIView animateWithDuration:0.25 animations:^{ self.bar.alpha = 0.0; }];
        else
            self.bar.alpha = 0.0;
    }
    NSMutableArray<UIView *> *fresh = [NSMutableArray array];
    for (UIView *v in [self targets]) {
        if ([self.fadedViews containsObject:v]) {
            if (v.alpha > 0.02 && !animated)
                JackZeroAlpha(v); // Instagram put it back; keep it gone
            else if (v.alpha > 0.02)
                [fresh addObject:v];
            continue;
        }
        if (v.hidden)
            continue;
        if (v.alpha < 0.02) {
            // Already invisible (Instagram is about to fade it in): own it anyway so it stays gone.
            if (!animated) {
                objc_setAssociatedObject(v, kJackSavedAlphaKey, @(v.alpha), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                [self.fadedViews addObject:v];
            }
            continue;
        }
        objc_setAssociatedObject(v, kJackSavedAlphaKey, @(v.alpha), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self.fadedViews addObject:v];
        [fresh addObject:v];
    }
    if (!self.faded && !fresh.count)
        return;
    self.faded = YES;
    gJackReelsFaded = YES;
    if (!fresh.count)
        return;
    void (^hide)(void) = ^{
        for (UIView *v in fresh)
            JackZeroAlpha(v);
    };
    if (animated)
        [UIView animateWithDuration:0.6 delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction animations:hide completion:nil];
    else
        hide();
}

- (void)showAnimated:(BOOL)animated {
    if (!self.faded)
        return;
    if (!self.controller.presentedViewController) {
        [self buildBar];
        [self refreshBar];
        if (animated)
            [UIView animateWithDuration:0.25 animations:^{ self.bar.alpha = 1.0; }];
        else
            self.bar.alpha = 1.0;
    }
    self.faded = NO;
    gJackReelsFaded = NO;
    NSArray<UIView *> *views = self.fadedViews.allObjects;
    [self.fadedViews removeAllObjects];
    void (^restore)(void) = ^{
        for (UIView *v in views) {
            NSNumber *a = objc_getAssociatedObject(v, kJackSavedAlphaKey);
            objc_setAssociatedObject(v, kJackSavedAlphaKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            v.alpha = a ? a.doubleValue : 1.0;
        }
    };
    if (animated)
        [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction animations:restore completion:nil];
    else
        restore();
}

@end

static JackReelsImmersive *JackImmersiveFor(UIViewController *vc) {
    JackReelsImmersive *m = objc_getAssociatedObject(vc, kJackReelsImmersiveKey);
    if (!m) {
        m = [JackReelsImmersive new];
        m.controller = vc;
        objc_setAssociatedObject(vc, kJackReelsImmersiveKey, m, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return m;
}

static void JackEnforceImmersiveForCell(UIView *cell) {
    if (!gJackReelsFaded)
        return;
    for (UIResponder *r = cell.nextResponder; r; r = r.nextResponder) {
        if ([r isKindOfClass:[UIViewController class]]) {
            for (UIViewController *c = (UIViewController *)r; c; c = c.parentViewController) {
                JackReelsImmersive *m = objc_getAssociatedObject(c, kJackReelsImmersiveKey);
                if (m) {
                    [m fadeCell:(UICollectionViewCell *)cell];
                    return;
                }
            }
            return;
        }
    }
}

%group JackReelsCellHooks

%hook UICollectionViewCell

- (void)layoutSubviews {
    %orig;
    if ([NSStringFromClass([self class]) hasPrefix:@"IGSundialViewer"])
        JackEnforceImmersiveForCell((UIView *)self);
}

- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)attrs {
    %orig;
    if ([NSStringFromClass([self class]) hasPrefix:@"IGSundialViewer"])
        JackEnforceImmersiveForCell((UIView *)self);
}

- (void)didMoveToWindow {
    %orig;
    if ([NSStringFromClass([self class]) hasPrefix:@"IGSundialViewer"] && [(UIView *)self window])
        JackEnforceImmersiveForCell((UIView *)self);
}

%end

// While full screen, Instagram fading a hidden control back in is ignored.
%hook UIView

- (void)setAlpha:(CGFloat)alpha {
    if (gJackReelsFaded && !gJackOwnAlphaWrite && objc_getAssociatedObject(self, kJackSavedAlphaKey)) {
        // Remember what Instagram wanted, so a tap restores exactly that; keep it hidden for now.
        objc_setAssociatedObject(self, kJackSavedAlphaKey, @(alpha), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        alpha = 0.0;
    }
    %orig(alpha);
}

%end

%end

%group JackReelsImmersiveHooks

%hook IGSundialFeedViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    [JackImmersiveFor((UIViewController *)self) start];
}

- (void)viewWillDisappear:(BOOL)animated {
    [JackImmersiveFor((UIViewController *)self) stop];
    %orig;
}

%end

%end

#pragma mark - Install

extern "C" void JackInstallRebornHooks(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Class header = SPKResolveIGClass(@"IGHomeFeedHeader.IGHomeFeedHeaderView", @"IGHomeFeedHeaderView");
        if (header)
            %init(JackFeedHeaderHooks, IGHomeFeedHeaderView = header);
        if (objc_getClass("IGTabBarButton") && objc_getClass("IGTabBarController"))
            %init(JackTabBarHooks);
        if (objc_getClass("IGBadgeData"))
            %init(JackBadgeHooks);
        %init(JackUpsellHooks);
        %init(JackInterestPromptHooks);
        if (objc_getClass("IGSundialFeedViewController"))
            %init(JackReelsImmersiveHooks);
        %init(JackReelsCellHooks);
        SPKLog(@"Jack", @"Reborn hooks header=%@", header ? NSStringFromClass(header) : @"(none)");

        // Badge permission (badge only; never alerts or sounds), then keep the icon current.
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
            if (settings.authorizationStatus == UNAuthorizationStatusNotDetermined)
                [center requestAuthorizationWithOptions:UNAuthorizationOptionBadge completionHandler:^(__unused BOOL granted, __unused NSError *error){
                }];
        }];
        for (NSNotificationName name in @[ UIApplicationWillResignActiveNotification, UIApplicationDidEnterBackgroundNotification,
                                           UIApplicationDidBecomeActiveNotification ]) {
            [[NSNotificationCenter defaultCenter] addObserverForName:name object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *n) {
                JackApplyAppBadge();
                JackRefreshHeartDots();
            }];
        }
    });
}
