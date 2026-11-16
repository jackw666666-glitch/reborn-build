// JACK BUILD ("Instagram Reborn"): settings chosen for Jack and locked in, so the app
// works the same without anyone opening Sparkle Settings. A locked key always reads
// this value, whatever is stored on the device or per account.
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// The locked value for `key`, or nil when the key is left to Sparkle as usual.
FOUNDATION_EXPORT id _Nullable SPKJackLockedPreference(NSString *key);

NS_ASSUME_NONNULL_END
