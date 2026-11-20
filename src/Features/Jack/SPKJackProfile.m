#import "SPKJackProfile.h"

// Keep the "Instagram Reborn — Feature Tracker" doc in step with this list.
id SPKJackLockedPreference(NSString *key) {
    static NSDictionary<NSString *, id> *locked;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        locked = @{
            // Threads: gone
            @"profile_hide_threads_btn" : @YES,
            @"feed_hide_suggested_threads" : @YES,

            // Reposting: button removed, and a confirm in case one turns up elsewhere
            @"feed_hide_repost_btn" : @YES,
            @"reels_hide_repost_btn" : @YES,
            @"feed_confirm_repost" : @YES,
            @"reels_confirm_repost" : @YES,

            // Stories: never tell people you watched (eye button sends it, with a confirm)
            @"stories_manual_seen_mode" : @"tap",
            @"stories_manual_seen_keep_local" : @YES,
            @"stories_mark_seen_on_like" : @YES, // liking a story shows you watched it (Jack 11/15)
            @"stories_mark_seen_on_reply" : @YES, // replies and emoji reactions show you watched (Jack 11/15)
            @"stories_confirm_mark_seen" : @YES,

            // Long-press previews of stories and chats
            @"stories_unlock_preview" : @YES,
            @"stories_hide_ig_plus_button" : @YES,
            @"msgs_unlock_preview" : @YES,

            // Story playback buttons (the playback one shows on video stories)
            @"stories_audio_toggle" : @YES,
            @"stories_playback_controls" : @YES,

            // Screenshots: no detection in disappearing messages, vanish mode, Instants
            @"msgs_disable_screenshot_detection" : @YES,
            @"msgs_hide_vanish_screenshot" : @YES,
            @"instants_allow_screenshot" : @YES,
            // Sparkle's own buttons never show up in screenshots or recordings
            @"interface_hide_ui_on_capture" : @YES,

            // Lower exposure: no desktop-browser imitation for 4K photos
            @"downloads_fetch_4k_images" : @NO,

            // Meta's promotions for its own products (Meta Verified / Meta One) out of the feed
            @"feed_hide_meta_promotions" : @YES,

            // Sparkle stays out of sight
            @"tools_open_settings_on_launch" : @NO,
            @"feed_header_button" : @NO,
            @"feed_disable_appicon_gesture" : @YES,
            @"profile_action_btn" : @YES, // its header hook also carries the profile heart

            // Reels can't be liked (tap or double-tap); unliking an old like still works
            @"reels_confirm_like" : @YES, @"reels_confirm_double_tap_like" : @YES, @"jack_block_reel_likes" : @YES,
            @"reels_tap_control" : @"pause", // Instagram's own tap pauses (the middle of the reel)
            @"reels_hide_like_count" : @YES, // like button itself is hidden in JackReborn.xm
            @"reels_disable_auto_unmute" : @YES, // reels start muted; the speaker button unmutes
            @"reels_hide_header" : @YES, // no Reels / Friends bar, plus or sliders button on top of reels

            // Messages tab = messages only
            @"instants_hide_in_inbox" : @YES, @"instants_disable_creation" : @YES, @"instants_camera_btn" : @NO,
            @"msgs_hide_notes_tray" : @YES, @"msgs_hide_friends_map" : @YES, @"msgs_hide_reels_blend" : @YES,
            @"msgs_hide_suggested_chats" : @YES, @"general_hide_suggested_users_msgs" : @YES, @"general_hide_meta_ai_msgs" : @YES,

            // No suggested accounts or posts anywhere
            @"general_hide_suggested_users_feed" : @YES, @"general_hide_suggested_users_profile" : @YES,
            @"general_hide_suggested_users_activity" : @YES, @"general_hide_suggested_users_reels" : @YES,
            @"general_hide_suggested_users_search" : @YES, @"general_hide_suggested_users_follow_lists" : @YES,
            @"general_hide_suggested_users_subscriptions" : @YES, @"stories_hide_suggested_accounts" : @YES,
            @"feed_hide_suggested_posts" : @NO, @"feed_hide_suggested_reels" : @NO, // you want "Suggested for you" posts
        };
    });
    return locked[key];
}
