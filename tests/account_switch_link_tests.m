#import <Foundation/Foundation.h>
#import "ApolloAccountSwitchLink.h"

static int sFailures = 0;

#define CHECK(cond, ...) do { \
    if (!(cond)) { sFailures++; fprintf(stderr, "FAIL %s:%d: %s\n", __FILE__, __LINE__, [NSString stringWithFormat:__VA_ARGS__].UTF8String); } \
} while (0)

static NSURL *U(NSString *string) { return [NSURL URLWithString:string]; }

static NSString *ParsedUsername(NSString *link) {
    NSString *username = nil;
    ApolloAccountSwitchLinkParse(U(link), &username, NULL);
    return username;
}

static NSString *ParsedKey(NSString *link) {
    NSString *key = nil;
    ApolloAccountSwitchLinkParse(U(link), NULL, &key);
    return key;
}

static void TestClaiming(void) {
    CHECK(ApolloAccountSwitchLinkIsAccountURL(U(@"apollo://reborn/account/alice?key=k")), @"well-formed link");
    CHECK(ApolloAccountSwitchLinkIsAccountURL(U(@"apollo://reborn/account")), @"bare /account is still claimed");
    CHECK(ApolloAccountSwitchLinkIsAccountURL(U(@"apollo://reborn/account/")), @"trailing slash");
    CHECK(ApolloAccountSwitchLinkIsAccountURL(U(@"APOLLO://Reborn/Account/Alice")), @"scheme, host and path are case-insensitive");
    CHECK(ApolloAccountSwitchLinkIsAccountURL(U(@"apollo://reborn/account/!!!")), @"malformed username is still claimed");
    CHECK(!ApolloAccountSwitchLinkIsAccountURL(U(@"apollo://reborn/accounts/alice")), @"accounts is a different route");
    CHECK(!ApolloAccountSwitchLinkIsAccountURL(U(@"apollo://reborn/settings/account-switching")), @"settings route");
    CHECK(!ApolloAccountSwitchLinkIsAccountURL(U(@"apollo://reddit.com/u/alice")), @"native user link");
    CHECK(!ApolloAccountSwitchLinkIsAccountURL(U(@"https://reborn/account/alice")), @"other scheme");
    CHECK(!ApolloAccountSwitchLinkIsAccountURL(nil), @"nil");
    CHECK(!ApolloAccountSwitchLinkParse(U(@"apollo://reborn/home"), NULL, NULL), @"Parse returns NO for other routes");
}

static void TestUsernames(void) {
    CHECK([ParsedUsername(@"apollo://reborn/account/Alice_99?key=k") isEqualToString:@"alice_99"], @"lowercased");
    CHECK([ParsedUsername(@"apollo://reborn/account/u/Alice?key=k") isEqualToString:@"alice"], @"u/ prefix");
    CHECK([ParsedUsername(@"apollo://reborn/account//u/Alice?key=k") isEqualToString:@"alice"], @"/u/ prefix");
    CHECK([ParsedUsername(@"apollo://reborn/account/U%2FAlice?key=k") isEqualToString:@"alice"], @"encoded U/ prefix");
    CHECK([ParsedUsername(@"apollo://reborn/account/%2Fu%2Fbob-smith") isEqualToString:@"bob-smith"], @"encoded /u/ prefix");
    CHECK([ParsedUsername(@"apollo://reborn/account%2Falice") isEqualToString:@"alice"], @"encoded separator");
    CHECK([ParsedUsername(@"apollo://reborn/account/alice/") isEqualToString:@"alice"], @"trailing slash dropped");
    CHECK([ParsedUsername(@"apollo://reborn/account/%20alice%20") isEqualToString:@"alice"], @"whitespace trimmed");
    CHECK(ParsedUsername(@"apollo://reborn/account?key=k") == nil, @"no username");
    CHECK(ParsedUsername(@"apollo://reborn/account/?key=k") == nil, @"empty username");
    CHECK(ParsedUsername(@"apollo://reborn/account/u/") == nil, @"prefix only");
    CHECK(ParsedUsername(@"apollo://reborn/account/u/u/alice") == nil, @"only one prefix is removed");
    CHECK(ParsedUsername(@"apollo://reborn/account/al%20ice") == nil, @"inner space");
    CHECK(ParsedUsername(@"apollo://reborn/account/al.ice") == nil, @"dot");
    CHECK(ParsedUsername(@"apollo://reborn/account/%C3%A9mile") == nil, @"non-ASCII");
    CHECK(ParsedUsername(@"apollo://reborn/account/a%2Fb") == nil, @"inner slash");
    CHECK(ParsedUsername([@"apollo://reborn/account/" stringByAppendingString:[@"" stringByPaddingToLength:65 withString:@"a" startingAtIndex:0]]) == nil, @"too long");
    CHECK([ApolloAccountSwitchLinkNormalizeUsername(@"/U/Some_User") isEqualToString:@"some_user"], @"normalize directly");
    CHECK(ApolloAccountSwitchLinkNormalizeUsername(nil) == nil, @"nil");
    CHECK(ApolloAccountSwitchLinkNormalizeUsername(@"%") == nil, @"bad escape");
}

static void TestKeyQuery(void) {
    CHECK([ParsedKey(@"apollo://reborn/account/alice?key=abc-_123") isEqualToString:@"abc-_123"], @"key read");
    CHECK([ParsedKey(@"apollo://reborn/account/alice?x=1&key=abc&key=other") isEqualToString:@"abc"], @"first key wins");
    CHECK(ParsedKey(@"apollo://reborn/account/alice") == nil, @"missing key");
    CHECK(ParsedKey(@"apollo://reborn/account/alice?key=") == nil, @"empty key");
    CHECK(ParsedKey(@"apollo://reborn/account/alice?KEY=abc") == nil, @"name is case-sensitive");
}

static void TestLinkBuilding(void) {
    NSString *key = ApolloAccountSwitchLinkGenerateKey();
    NSString *link = ApolloAccountSwitchLinkURLString(@"Some_User", key);
    NSString *expected = [@"apollo://reborn/account/Some_User?key=" stringByAppendingString:key];
    CHECK([link isEqualToString:expected], @"link %@", link);
    NSString *username = nil, *parsedKey = nil;
    CHECK(ApolloAccountSwitchLinkParse(U(link), &username, &parsedKey), @"round trip parses");
    CHECK([username isEqualToString:@"some_user"] && [parsedKey isEqualToString:key], @"round trip values");
    CHECK([ParsedKey(ApolloAccountSwitchLinkURLString(@"a", @"x&y=z")) isEqualToString:@"x&y=z"], @"query characters are escaped");
}

static void TestKeys(void) {
    NSString *a = ApolloAccountSwitchLinkGenerateKey();
    NSString *b = ApolloAccountSwitchLinkGenerateKey();
    CHECK(a.length == 43, @"32 bytes base64url unpadded is 43 chars, got %lu", (unsigned long)a.length);
    CHECK(![a isEqualToString:b], @"keys differ");
    NSCharacterSet *alphabet = [NSCharacterSet characterSetWithCharactersInString:
        @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"];
    CHECK([a rangeOfCharacterFromSet:alphabet.invertedSet].location == NSNotFound, @"base64url alphabet only: %@", a);

    uint8_t raw[] = { 0xfb, 0xff, 0xfe };
    CHECK([ApolloAccountSwitchLinkBase64URLEncode([NSData dataWithBytes:raw length:3]) isEqualToString:@"-__-"], @"url alphabet");
    uint8_t one[] = { 0x00 };
    CHECK([ApolloAccountSwitchLinkBase64URLEncode([NSData dataWithBytes:one length:1]) isEqualToString:@"AA"], @"no padding");

    CHECK(ApolloAccountSwitchLinkKeysEqual(a, [a mutableCopy]), @"equal keys");
    CHECK(!ApolloAccountSwitchLinkKeysEqual(a, b), @"different keys");
    CHECK(!ApolloAccountSwitchLinkKeysEqual([a substringToIndex:42], a), @"prefix is not equal");
    CHECK(!ApolloAccountSwitchLinkKeysEqual(a, nil), @"no stored key");
    CHECK(!ApolloAccountSwitchLinkKeysEqual(nil, a), @"no provided key");
    CHECK(!ApolloAccountSwitchLinkKeysEqual(@"", @""), @"empty never equal");
    CHECK(!ApolloAccountSwitchLinkKeysEqual(nil, nil), @"nil never equal");

    CHECK([ApolloAccountSwitchLinkMaskedKey(@"abcdefgh") isEqualToString:@"abcd•••"], @"mask");
    CHECK([ApolloAccountSwitchLinkMaskedKey(@"ab") isEqualToString:@"ab•••"], @"short mask");
    CHECK([ApolloAccountSwitchLinkMaskedKey(nil) isEqualToString:@""], @"nil mask");
}

static void TestEvaluate(void) {
    NSString *key = @"secret";
    CHECK(ApolloAccountSwitchLinkEvaluate(YES, NO, key, key, @"alice") == ApolloAccountSwitchLinkVerdictAccept, @"accept");
    CHECK(ApolloAccountSwitchLinkEvaluate(YES, YES, key, key, @"alice") == ApolloAccountSwitchLinkVerdictIgnore, @"lockout beats a right key");
    CHECK(ApolloAccountSwitchLinkEvaluate(NO, NO, key, key, @"alice") == ApolloAccountSwitchLinkVerdictRejectDisabled, @"feature off");
    CHECK(ApolloAccountSwitchLinkEvaluate(YES, NO, key, @"wrong", @"alice") == ApolloAccountSwitchLinkVerdictRejectKey, @"wrong key");
    CHECK(ApolloAccountSwitchLinkEvaluate(YES, NO, key, nil, @"alice") == ApolloAccountSwitchLinkVerdictRejectKey, @"missing key");
    CHECK(ApolloAccountSwitchLinkEvaluate(YES, NO, nil, @"anything", @"alice") == ApolloAccountSwitchLinkVerdictRejectKey, @"no stored key");
    CHECK(ApolloAccountSwitchLinkEvaluate(YES, NO, key, @"wrong", nil) == ApolloAccountSwitchLinkVerdictRejectKey, @"key is checked before the username");
    CHECK(ApolloAccountSwitchLinkEvaluate(YES, NO, key, key, nil) == ApolloAccountSwitchLinkVerdictRejectUsername, @"right key, no username");
}

static void TestLockout(void) {
    ApolloAccountSwitchLinkLockout lockout = {0};
    for (int i = 0; i < 4; i++) {
        CHECK(!ApolloAccountSwitchLinkLockoutRecordFailure(&lockout, 100 + i), @"failure %d is not a lockout", i + 1);
    }
    CHECK(ApolloAccountSwitchLinkLockoutRecordFailure(&lockout, 104), @"fifth failure locks out");
    CHECK(ApolloAccountSwitchLinkLockoutRecordFailure(&lockout, 100000), @"lockout lasts for the process");

    // Failures spread over more than 10 minutes never lock out.
    ApolloAccountSwitchLinkLockout spread = {0};
    for (int i = 0; i < 20; i++) {
        CHECK(!ApolloAccountSwitchLinkLockoutRecordFailure(&spread, i * 151.0), @"spread failure %d", i + 1);
    }

    // The window slides: four old failures expire, then five recent ones lock.
    ApolloAccountSwitchLinkLockout sliding = {0};
    for (int i = 0; i < 4; i++) ApolloAccountSwitchLinkLockoutRecordFailure(&sliding, i);
    CHECK(!ApolloAccountSwitchLinkLockoutRecordFailure(&sliding, 600.0), @"oldest failure is exactly 10 minutes old and expired");
    CHECK(sliding.count == 4, @"expired failure pruned, count %lu", (unsigned long)sliding.count);
    // At 601 the failure at 1s has aged out too, so it's still four.
    CHECK(!ApolloAccountSwitchLinkLockoutRecordFailure(&sliding, 601.0), @"failure at 1s expired at 601s");
    CHECK(ApolloAccountSwitchLinkLockoutRecordFailure(&sliding, 601.5), @"five inside the window (2, 3, 600, 601, 601.5) lock out");
}

int main(void) {
    @autoreleasepool {
        TestClaiming();
        TestUsernames();
        TestKeyQuery();
        TestLinkBuilding();
        TestKeys();
        TestEvaluate();
        TestLockout();
    }
    if (sFailures > 0) {
        fprintf(stderr, "%d account switch link check(s) failed\n", sFailures);
        return 1;
    }
    printf("account switch link tests passed\n");
    return 0;
}
