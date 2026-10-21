#import <Foundation/Foundation.h>

// The secret key behind apollo://reborn/account/<username>?key=<secret> links
// (see ApolloAccountSwitchLink.h). It lives only in the keychain, readable
// after first unlock, under a service that ApolloBackupRestore's allowlist
// (ApolloBackupOwnsKeychainIdentity) does not own, so backups never capture it
// and restores never write it. A restore deletes it instead, and the next use
// generates a fresh one. Main thread only.

NS_ASSUME_NONNULL_BEGIN

__BEGIN_DECLS

extern NSString *const ApolloAccountSwitchLinkKeychainService;
extern NSString *const ApolloAccountSwitchLinkKeychainAccount;

// The stored key, or nil when there is none (or the keychain can't be read yet).
NSString *_Nullable ApolloAccountSwitchLinkStoredKey(void);

// The stored key, generating and storing one first if there is none. nil only
// if the key could not be generated or saved.
NSString *_Nullable ApolloAccountSwitchLinkEnsureKey(void);

// Replaces the key with a new one. Returns the new key, or nil (old key kept)
// if it could not be generated or saved.
NSString *_Nullable ApolloAccountSwitchLinkRegenerateKey(void);

// Deletes the key. Called by settings restore.
void ApolloAccountSwitchLinkForgetKey(void);

__END_DECLS

NS_ASSUME_NONNULL_END
