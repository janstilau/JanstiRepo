#import "common.h"

#define	EXPOSE_NSURLCredentialStorage_IVARS	1
#import "GSURLPrivate.h"

NSString *const NSURLCredentialStorageChangedNotification
= @"NSURLCredentialStorageChangedNotification";

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
        [gnustep_global_lock unlock];
    }
    return storage;
}

- (NSDictionary *) allCredentials
{
    NSMutableDictionary	*all;
    NSEnumerator		*enumerator;
    NSURLProtectionSpace	*space;
    
    all = [NSMutableDictionary dictionaryWithCapacity: [self->credentials count]];
    enumerator = [self->credentials keyEnumerator];
    while ((space = [enumerator nextObject]) != nil)
    {
        NSDictionary	*info = [[self->credentials objectForKey: space] copy];
        
        [all setObject: info forKey: space];
        RELEASE(info);
    }
    return all;
}

- (NSDictionary *) credentialsForProtectionSpace: (NSURLProtectionSpace *)space
{
    return AUTORELEASE([[self->credentials objectForKey: space] copy]);
}

- (NSURLCredential *) defaultCredentialForProtectionSpace:
(NSURLProtectionSpace *)space
{
    return [self->defaults objectForKey: space];
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
    if (credential == nil || ![credential isKindOfClass: [NSURLCredential class]])
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"[%@-%@] nil or bad  class for credential",
         NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
    if (space == nil || ![space isKindOfClass: [NSURLProtectionSpace class]])
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"[%@-%@] nil or bad  class for space",
         NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
    [[self->credentials objectForKey: space]
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
    
    if (credential == nil || ![credential isKindOfClass: [NSURLCredential class]])
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"[%@-%@] nil or bad  class for credential",
         NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
    if (space == nil || ![space isKindOfClass: [NSURLProtectionSpace class]])
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"[%@-%@] nil or bad  class for space",
         NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
    info = [self->credentials objectForKey: space];
    if (info == nil)
    {
        info = [NSMutableDictionary new];
        [self->credentials setObject: info forKey: space];
        RELEASE(info);
    }
    [info setObject: credential forKey: [credential user]];
}

/**
 * Sets the default credential for the protection space.  Also calls
 * -setCredential:forProtectionSpace: if the credential has not already
 * been set in space.
 */
- (void) setDefaultCredential: (NSURLCredential *)credential
           forProtectionSpace: (NSURLProtectionSpace *)space
{
    if (credential == nil || ![credential isKindOfClass: [NSURLCredential class]])
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"[%@-%@] nil or bad  class for credential",
         NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
    if (space == nil || ![space isKindOfClass: [NSURLProtectionSpace class]])
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"[%@-%@] nil or bad  class for space",
         NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
    [self->defaults setObject: credential forKey: space];
    if ([[self->credentials objectForKey: space] objectForKey: [credential user]]
        != credential)
    {
        [self setCredential: credential forProtectionSpace: space];
    }
}

@end

