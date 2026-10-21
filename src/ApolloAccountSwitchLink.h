#import <Foundation/Foundation.h>

// Shortcut account switching: apollo://reborn/account/<username>?key=<secret>
//
// This half is Foundation-only (plus Security/CommonCrypto) so the whole of it
// compiles into a host-side harness: tests/run_account_switch_link_tests.sh.
// The keychain store and the switching itself live in
// ApolloAccountSwitchLinkStore.m and ApolloQuickActions.xm /
// ApolloAccountSwitcherViewController.xm.
//
// Privacy: nothing here logs. Callers must never log the key, the link, or the
// username either (see ApolloQuickActions.xm for the log lines they do write).

NS_ASSUME_NONNULL_BEGIN

__BEGIN_DECLS

#pragma mark - Parsing

// YES for every apollo://reborn/account and apollo://reborn/account/... URL,
// well-formed or not. The URL handler claims all of these so Apollo's native
// router never sees one, even when the link is rejected.
BOOL ApolloAccountSwitchLinkIsAccountURL(NSURL *_Nullable url);

// Parses an account link. Returns NO when url is not an account link at all.
// When it is one, returns YES and sets:
//   *outUsername: the normalized username (see below), or nil if the path
//                 carries no usable username
//   *outKey:      the first `key` query value, or nil if absent/empty
BOOL ApolloAccountSwitchLinkParse(NSURL *_Nullable url,
                                  NSString *_Nullable *_Nullable outUsername,
                                  NSString *_Nullable *_Nullable outKey);

// Percent-decodes, trims, drops one leading "u/" or "/u/" (any case) and
// lowercases. Returns nil unless what's left is 1-64 characters of
// [A-Za-z0-9_-], which covers every Reddit username.
NSString *_Nullable ApolloAccountSwitchLinkNormalizeUsername(NSString *_Nullable raw);

// apollo://reborn/account/<username>?key=<key>, with the key form-escaped.
NSString *ApolloAccountSwitchLinkURLString(NSString *username, NSString *key);

#pragma mark - Key

// 32 bytes from SecRandomCopyBytes, base64url-encoded without padding (43
// characters). Returns nil only if the system RNG fails.
NSString *_Nullable ApolloAccountSwitchLinkGenerateKey(void);

// Base64url (RFC 4648 §5) without padding.
NSString *ApolloAccountSwitchLinkBase64URLEncode(NSData *data);

// Constant-time comparison. Both sides are hashed with SHA-256 first, so the
// time taken depends on neither the contents nor the length of the stored key.
// nil or empty on either side is never equal.
BOOL ApolloAccountSwitchLinkKeysEqual(NSString *_Nullable provided, NSString *_Nullable stored);

// The masked form shown in settings: first 4 characters + "•••".
NSString *ApolloAccountSwitchLinkMaskedKey(NSString *_Nullable key);

#pragma mark - Decision

typedef NS_ENUM(NSInteger, ApolloAccountSwitchLinkVerdict) {
    ApolloAccountSwitchLinkVerdictIgnore = 0,   // locked out: claim the link, do nothing, say nothing
    ApolloAccountSwitchLinkVerdictRejectDisabled, // feature off (doesn't count towards the lockout)
    ApolloAccountSwitchLinkVerdictRejectKey,      // key missing or wrong (counts towards the lockout)
    ApolloAccountSwitchLinkVerdictRejectUsername, // right key, but no usable username in the path
    ApolloAccountSwitchLinkVerdictAccept,
};

// Everything the handler decides before touching any account. The key is
// checked before the username so a rejection never depends on whether the
// username exists.
ApolloAccountSwitchLinkVerdict ApolloAccountSwitchLinkEvaluate(BOOL enabled,
                                                               BOOL lockedOut,
                                                               NSString *_Nullable storedKey,
                                                               NSString *_Nullable providedKey,
                                                               NSString *_Nullable username);

#pragma mark - Lockout

enum {
    ApolloAccountSwitchLinkMaxFailures = 5,
};
static const NSTimeInterval ApolloAccountSwitchLinkFailureWindow = 10 * 60;

// Bad-key attempts within a sliding 10-minute window. Five of them lock links
// out for the rest of the process (until Apollo is relaunched); there is no
// unlock and nothing persists. Times are seconds on a monotonic clock, passed
// in so tests can drive them. Not thread-safe: use it from the main thread.
typedef struct {
    NSTimeInterval failures[ApolloAccountSwitchLinkMaxFailures];
    NSUInteger count;
    BOOL lockedOut;
} ApolloAccountSwitchLinkLockout;

// Records one bad attempt at `now` and returns whether links are now locked out.
BOOL ApolloAccountSwitchLinkLockoutRecordFailure(ApolloAccountSwitchLinkLockout *lockout, NSTimeInterval now);

__END_DECLS

NS_ASSUME_NONNULL_END
