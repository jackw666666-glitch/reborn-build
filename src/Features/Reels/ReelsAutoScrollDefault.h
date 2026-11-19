#import <Foundation/Foundation.h>

// The Auto Scroll mode actually in force: "default", "on" or "off". Disable
// Scrolling Reels forces "off" without touching the saved choice.
FOUNDATION_EXPORT NSString *SPKReelsAutoScrollEffectiveMode(void);

// Jack build: Instagram's auto scroll controller (nil until Reels has opened) and whether it is on.
FOUNDATION_EXPORT id JackReelsAutoScrollController(void);
FOUNDATION_EXPORT BOOL JackReelsAutoScrollOn(void);
