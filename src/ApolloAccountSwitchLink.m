#import "ApolloAccountSwitchLink.h"

#import <CommonCrypto/CommonDigest.h>
#import <Security/Security.h>
#import <string.h>

#pragma mark - Parsing

static BOOL ApolloAccountSwitchLinkIsRebornURL(NSURL *url) {
    if (![url isKindOfClass:[NSURL class]]) return NO;
    if (![[url.scheme lowercaseString] isEqualToString:@"apollo"]) return NO;
    NSString *host = [[url.host lowercaseString] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return [host isEqualToString:@"reborn"];
}

BOOL ApolloAccountSwitchLinkIsAccountURL(NSURL *url) {
    if (!ApolloAccountSwitchLinkIsRebornURL(url)) return NO;
    // Same trimming as ApolloQuickActionNameFromURL, so "/account/" and
    // "account" (no leading slash) are claimed alike.
    NSString *path = [[url.path lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]];
    return [path isEqualToString:@"account"] || [path hasPrefix:@"account/"];
}

NSString *ApolloAccountSwitchLinkNormalizeUsername(NSString *raw) {
    if (![raw isKindOfClass:[NSString class]]) return nil;
    NSString *name = [raw stringByRemovingPercentEncoding] ?: raw;
    name = [name stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    // One "u/" or "/u/" prefix, as Reddit writes usernames.
    if ([name.lowercaseString hasPrefix:@"/u/"]) {
        name = [name substringFromIndex:3];
    } else if ([name.lowercaseString hasPrefix:@"u/"]) {
        name = [name substringFromIndex:2];
    }
    // A Shortcut that appends "/" still means the same account.
    while ([name hasSuffix:@"/"]) name = [name substringToIndex:name.length - 1];

    if (name.length == 0 || name.length > 64) return nil;
    static NSCharacterSet *sInvalid = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sInvalid = [[NSCharacterSet characterSetWithCharactersInString:
            @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"] invertedSet];
    });
    if ([name rangeOfCharacterFromSet:sInvalid].location != NSNotFound) return nil;
    return name.lowercaseString;
}

BOOL ApolloAccountSwitchLinkParse(NSURL *url, NSString **outUsername, NSString **outKey) {
    if (outUsername) *outUsername = nil;
    if (outKey) *outKey = nil;
    if (!ApolloAccountSwitchLinkIsAccountURL(url)) return NO;

    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    // Work on the still-encoded path so a username sent as "u%2Fname" is
    // decoded exactly once, by the normalizer.
    NSString *encodedPath = components.percentEncodedPath ?: @"";
    while ([encodedPath hasPrefix:@"/"]) encodedPath = [encodedPath substringFromIndex:1];
    // "account/<name>", or "account%2F<name>" when the separator itself was
    // encoded (url.path decodes it, so IsAccountURL accepted it).
    NSString *lowerPath = encodedPath.lowercaseString;
    NSString *remainder = @"";
    if ([lowerPath hasPrefix:@"account/"]) {
        remainder = [encodedPath substringFromIndex:@"account/".length];
    } else if ([lowerPath hasPrefix:@"account%2f"]) {
        remainder = [encodedPath substringFromIndex:@"account%2f".length];
    }
    if (outUsername) *outUsername = ApolloAccountSwitchLinkNormalizeUsername(remainder);

    for (NSURLQueryItem *item in components.queryItems) {
        if (![item.name isEqualToString:@"key"]) continue;
        if (outKey && item.value.length > 0) *outKey = item.value;
        break;
    }
    return YES;
}

NSString *ApolloAccountSwitchLinkURLString(NSString *username, NSString *key) {
    NSMutableCharacterSet *allowed = [NSCharacterSet.URLQueryAllowedCharacterSet mutableCopy];
    [allowed removeCharactersInString:@"&=+?#/"];
    NSString *encodedName = [username stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLPathAllowedCharacterSet] ?: @"";
    NSString *encodedKey = [key stringByAddingPercentEncodingWithAllowedCharacters:allowed] ?: @"";
    return [NSString stringWithFormat:@"apollo://reborn/account/%@?key=%@", encodedName, encodedKey];
}

#pragma mark - Key

NSString *ApolloAccountSwitchLinkBase64URLEncode(NSData *data) {
    NSString *base64 = [data base64EncodedStringWithOptions:0];
    base64 = [base64 stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
    base64 = [base64 stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    return [base64 stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"="]];
}

NSString *ApolloAccountSwitchLinkGenerateKey(void) {
    uint8_t bytes[32];
    if (SecRandomCopyBytes(kSecRandomDefault, sizeof(bytes), bytes) != errSecSuccess) return nil;
    NSString *key = ApolloAccountSwitchLinkBase64URLEncode([NSData dataWithBytes:bytes length:sizeof(bytes)]);
    memset_s(bytes, sizeof(bytes), 0, sizeof(bytes));
    return key;
}

static void ApolloAccountSwitchLinkDigest(NSString *string, uint8_t out[CC_SHA256_DIGEST_LENGTH]) {
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding] ?: [NSData data];
    CC_SHA256(data.bytes, (CC_LONG)data.length, out);
}

BOOL ApolloAccountSwitchLinkKeysEqual(NSString *provided, NSString *stored) {
    BOOL usable = [provided isKindOfClass:[NSString class]] && provided.length > 0 &&
                  [stored isKindOfClass:[NSString class]] && stored.length > 0;
    uint8_t providedDigest[CC_SHA256_DIGEST_LENGTH];
    uint8_t storedDigest[CC_SHA256_DIGEST_LENGTH];
    ApolloAccountSwitchLinkDigest(usable ? provided : @"", providedDigest);
    ApolloAccountSwitchLinkDigest(usable ? stored : @"-", storedDigest);
    // timingsafe_bcmp touches every byte whatever it finds.
    BOOL equal = timingsafe_bcmp(providedDigest, storedDigest, sizeof(providedDigest)) == 0;
    return usable && equal;
}

NSString *ApolloAccountSwitchLinkMaskedKey(NSString *key) {
    if (![key isKindOfClass:[NSString class]] || key.length == 0) return @"";
    NSUInteger shown = MIN((NSUInteger)4, key.length);
    return [[key substringToIndex:shown] stringByAppendingString:@"•••"];
}

#pragma mark - Decision

ApolloAccountSwitchLinkVerdict ApolloAccountSwitchLinkEvaluate(BOOL enabled,
                                                               BOOL lockedOut,
                                                               NSString *storedKey,
                                                               NSString *providedKey,
                                                               NSString *username) {
    if (lockedOut) return ApolloAccountSwitchLinkVerdictIgnore;
    if (!enabled) return ApolloAccountSwitchLinkVerdictRejectDisabled;
    if (!ApolloAccountSwitchLinkKeysEqual(providedKey, storedKey)) return ApolloAccountSwitchLinkVerdictRejectKey;
    if (username.length == 0) return ApolloAccountSwitchLinkVerdictRejectUsername;
    return ApolloAccountSwitchLinkVerdictAccept;
}

#pragma mark - Lockout

BOOL ApolloAccountSwitchLinkLockoutRecordFailure(ApolloAccountSwitchLinkLockout *lockout, NSTimeInterval now) {
    if (!lockout) return NO;
    if (lockout->lockedOut) return YES;

    // Keep only failures still inside the window, oldest first.
    NSUInteger kept = 0;
    for (NSUInteger i = 0; i < lockout->count; i++) {
        if (now - lockout->failures[i] < ApolloAccountSwitchLinkFailureWindow) {
            lockout->failures[kept++] = lockout->failures[i];
        }
    }
    lockout->count = kept;
    lockout->failures[lockout->count++] = now;
    if (lockout->count >= ApolloAccountSwitchLinkMaxFailures) lockout->lockedOut = YES;
    return lockout->lockedOut;
}
