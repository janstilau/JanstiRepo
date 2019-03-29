#import "common.h"

#define	EXPOSE_NSURLCredentialStorage_IVARS	1
#import "GSURLPrivate.h"

NSString *const NSURLCredentialStorageChangedNotification
= @"NSURLCredentialStorageChangedNotification";

// Internal data storage
typedef struct {
    NSMutableDictionary	*credentials;
    NSMutableDictionary	*defaults;
} Internal;

#define	this	((Internal*)(self->_NSURLCredentialStorageInternal))

@implementation	NSURLCredentialStorage

static NSURLCredentialStorage	*storage = nil;

+ (id) allocWithZone: (NSZone*)z
{
    return RETAIN([self sharedCredentialStorage]);
}

+ (NSURLCredentialStorage *) sharedCredentialStorage
{
    if (storage == nil)
    {
        [gnustep_global_lock lock];
        if (storage == nil)
        {
            NSURLCredentialStorage	*createdStorage;
            createdStorage = (NSURLCredentialStorage*)
            NSAllocateObject(self, 0, NSDefaultMallocZone());
            createdStorage->_NSURLCredentialStorageInternal = (Internal*)
            NSZoneCalloc(NSDefaultMallocZone(), 1, sizeof(Internal));
            ((Internal*)(createdStorage->_NSURLCredentialStorageInternal))->credentials
            = [NSMutableDictionary new];
            ((Internal*)(createdStorage->_NSURLCredentialStorageInternal))->defaults
            = [NSMutableDictionary new];
            storage = createdStorage;
        }
        [gnustep_global_lock unlock];
    }
    return storage;
}

- (NSDictionary *) allCredentials
{
    NSMutableDictionary	*all;
    NSEnumerator		*enumerator;
    NSURLProtectionSpace	*space;
    
    all = [NSMutableDictionary dictionaryWithCapacity: [this->credentials count]];
    enumerator = [this->credentials keyEnumerator];
    while ((space = [enumerator nextObject]) != nil)
    {
        NSDictionary	*info = [[this->credentials objectForKey: space] copy];
        
        [all setObject: info forKey: space];
        RELEASE(info);
    }
    return all; // 复制了一份, 不会传递原始的数据出去.
}

- (NSDictionary *) credentialsForProtectionSpace: (NSURLProtectionSpace *)space
{
    return AUTORELEASE([[this->credentials objectForKey: space] copy]); // space 里面有着专门的 hash 函数, 就是因为它要在这里做 key 值.
}

- (void) dealloc
{
    [NSException raise: NSInternalInconsistencyException
                format: @"Attempt to deallocate credential storage"];
}

- (NSURLCredential *) defaultCredentialForProtectionSpace:
(NSURLProtectionSpace *)space
{
    return [this->defaults objectForKey: space];
}

// Should never be called.
- (id) init
{
    DESTROY(self);
    return nil;
}

- (void) removeCredential: (NSURLCredential *)credential
       forProtectionSpace: (NSURLProtectionSpace *)space
{
    [[this->credentials objectForKey: space]
     removeObjectForKey: [credential user]];
}

/**
 * Sets credential in the storage for the protection space specified.<br />
 * This replaces any old value with the same username.
 */
- (void) setCredential: (NSURLCredential *)credential
    forProtectionSpace: (NSURLProtectionSpace *)space
{
    NSMutableDictionary	*info;
    info = [this->credentials objectForKey: space];
    if (info == nil)
    {
        info = [NSMutableDictionary new];
        [this->credentials setObject: info forKey: space];
        RELEASE(info);
    }
    [info setObject: credential forKey: [credential user]]; // 这里, 一个 user 一个 credential, 因为现在 gnu 只实现了 user/password 的 credential 了.
}

/**
 * Sets the default credential for the protection space.  Also calls
 * -setCredential:forProtectionSpace: if the credential has not already
 * been set in space.
 */
- (void) setDefaultCredential: (NSURLCredential *)credential
           forProtectionSpace: (NSURLProtectionSpace *)space
{
    [this->defaults setObject: credential forKey: space];
    if ([[this->credentials objectForKey: space] objectForKey: [credential user]]
        != credential)
    {
        [self setCredential: credential forProtectionSpace: space];
    }
}

@end

