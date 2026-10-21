#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// Apollo-Reborn's own account switcher: lists every signed-in account with a
// per-account API-key status badge, and lets the user edit/clear each
// account's Reddit OAuth credentials (see ApolloAccountCredentials.{h,m}).
//
// Visually this fully replaces Apollo's native AccountManagerViewController,
// but every actual switch/add/delete is performed by driving a real, live
// instance of that native class through its existing ObjC-visible selectors
// (verified via Hopper decompilation of -[AccountManagerViewController
// tableView:didSelectRowAtIndexPath:] / -addBarButtonItemTapped: /
// -tableView:commitEditingStyle:forRowAtIndexPath:) — so account persistence,
// keychain writes, and OAuth add-account flows are still 100% Apollo's own
// code, not a reimplementation.
@interface ApolloAccountSwitcherViewController : UITableViewController

// Whether the custom switcher should be presented in place of Apollo's
// native AccountManagerViewController. Backed by UDKeyUseCustomAccountSwitcher
// (default YES) — flip to NO via defaults as an emergency fallback to the
// stock switcher if a future Apollo build changes the native ObjC selector
// surface this file drives (see ApolloAccountSwitcherViewController.xm).
+ (BOOL)isAvailable;

@end

#pragma mark - Shortcut account-switch links

// How a link-driven switch ended. displayName (passed alongside) is the
// account's username as Apollo spells it, or nil when no account matched.
typedef NS_ENUM(NSInteger, ApolloAccountLinkSwitchOutcome) {
    ApolloAccountLinkSwitchOutcomeSwitched = 0,
    ApolloAccountLinkSwitchOutcomeAlreadyActive,
    ApolloAccountLinkSwitchOutcomeUnknownAccount,
    // The account manager is already on screen, a native reorder is running,
    // another screen is presented over the tabs, or another link switch is
    // still in flight. Nothing was changed.
    ApolloAccountLinkSwitchOutcomeBusy,
    // Apollo's account manager didn't appear or didn't switch.
    ApolloAccountLinkSwitchOutcomeFailed,
};

typedef void (^ApolloAccountLinkSwitchCompletion)(ApolloAccountLinkSwitchOutcome outcome,
                                                  NSString *_Nullable displayName);

__BEGIN_DECLS

// Switches to the signed-in account whose username matches `username`
// (already normalized: lowercased, no "u/"). It drives Apollo's own switch:
// opens AccountManagerViewController through ProfileViewController's
// accountsBarButtonItemTappedWithSender: (the path the Accounts button and
// the Profile tab long-press use, which sets accountSwitchType), without
// animation, selects the matching row with the live instance's
// tableView:didSelectRowAtIndexPath: (as the switcher overlay does), then
// dismisses it. The row comes from AccountManager's live `accounts` array,
// read again once the manager is on screen.
//
// Returns NO, having done nothing, while the tab bar, Profile tab or account
// list isn't up yet (cold start), so the caller can retry. Otherwise returns
// YES and calls completion exactly once on the main thread. Main thread only.
BOOL ApolloAccountSwitcherSwitchToUsername(NSString *username, ApolloAccountLinkSwitchCompletion completion);

// The signed-in usernames in Apollo's live account order, spelled as Apollo
// has them, or nil when the live list can't be read. Main thread only.
NSArray<NSString *> *_Nullable ApolloAccountSwitcherLiveUsernames(void);

__END_DECLS

NS_ASSUME_NONNULL_END
