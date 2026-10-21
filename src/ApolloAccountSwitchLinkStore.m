#import "ApolloAccountSwitchLinkStore.h"

#import "ApolloAccountSwitchLink.h"
#import "ApolloCommon.h"
#import <Security/Security.h>

// Deliberately not "…Apollo.kagi"/"…Apollo.webjson" or a Valet service name:
// those are the only identities Backup & Restore owns.
NSString *const ApolloAccountSwitchLinkKeychainService = @"com.christianselig.Apollo.accountswitch";
NSString *const ApolloAccountSwitchLinkKeychainAccount = @"linkKey";

NSString *ApolloAccountSwitchLinkStoredKey(void) {
    CFDictionaryRef query = ApolloCreateGenericPasswordDataQuery((__bridge CFStringRef)ApolloAccountSwitchLinkKeychainService,
                                                                 (__bridge CFStringRef)ApolloAccountSwitchLinkKeychainAccount);
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching(query, &result);
    CFRelease(query);
    if (status != errSecSuccess || !result) {
        if (result) CFRelease(result);
        if (status != errSecItemNotFound) ApolloLog(@"[AccountLink] Key read failed (OSStatus %d)", (int)status);
        return nil;
    }
    if (CFGetTypeID(result) != CFDataGetTypeID()) {
        CFRelease(result);
        return nil;
    }
    NSData *data = CFBridgingRelease(result);
    NSString *key = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return key.length ? key : nil;
}

static BOOL ApolloAccountSwitchLinkSaveKey(NSString *key) {
    NSData *data = [key dataUsingEncoding:NSUTF8StringEncoding];
    OSStatus status = ApolloUpsertGenericPasswordData((__bridge CFStringRef)ApolloAccountSwitchLinkKeychainService,
                                                      (__bridge CFStringRef)ApolloAccountSwitchLinkKeychainAccount,
                                                      data, kSecAttrAccessibleAfterFirstUnlock);
    if (status != errSecSuccess) {
        ApolloLog(@"[AccountLink] Key save failed (OSStatus %d)", (int)status);
        return NO;
    }
    return YES;
}

NSString *ApolloAccountSwitchLinkEnsureKey(void) {
    NSString *key = ApolloAccountSwitchLinkStoredKey();
    if (key) return key;
    return ApolloAccountSwitchLinkRegenerateKey();
}

NSString *ApolloAccountSwitchLinkRegenerateKey(void) {
    NSString *key = ApolloAccountSwitchLinkGenerateKey();
    if (!key) {
        ApolloLog(@"[AccountLink] Key generation failed");
        return nil;
    }
    if (!ApolloAccountSwitchLinkSaveKey(key)) return nil;
    ApolloLog(@"[AccountLink] Generated a new key");
    return key;
}

void ApolloAccountSwitchLinkForgetKey(void) {
    CFDictionaryRef identity = ApolloCreateGenericPasswordIdentity((__bridge CFStringRef)ApolloAccountSwitchLinkKeychainService,
                                                                    (__bridge CFStringRef)ApolloAccountSwitchLinkKeychainAccount);
    OSStatus status = SecItemDelete(identity);
    CFRelease(identity);
    if (status != errSecSuccess && status != errSecItemNotFound) {
        ApolloLog(@"[AccountLink] Key removal failed (OSStatus %d)", (int)status);
    }
}
