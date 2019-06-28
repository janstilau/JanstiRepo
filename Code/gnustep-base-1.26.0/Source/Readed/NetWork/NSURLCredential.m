#import "common.h"

#define	EXPOSE_NSURLCredential_IVARS	1
#import "GSURLPrivate.h"

@implementation	NSURLCredential

+ (id) allocWithZone: (NSZone*)z
{
    NSURLCredential	*o = [super allocWithZone: z];
    return o;
}

+ (NSURLCredential *) credentialWithUser: (NSString *)user
                                password: (NSString *)password
                             persistence: (NSURLCredentialPersistence)persistence
{
    NSURLCredential	*o = [self alloc];
    
    o = [o initWithUser: user password: password persistence: persistence];
    return AUTORELEASE(o);
}

- (id) copyWithZone: (NSZone*)z
{
    NSURLCredential	*o;
    return o;
}

- (BOOL) hasPassword
{
    return hasPassword;
}

- (NSUInteger) hash
{
    return [user hash];
}

- (id) initWithUser: (NSString *)user
           password: (NSString *)password
        persistence: (NSURLCredentialPersistence)persistence
{
    if (user == nil)
    {
        return nil;
    }
    if ((self = [super init]) != nil)
    {
        if (persistence == NSURLCredentialPersistenceSynchronizable)
        {
            persistence = NSURLCredentialPersistencePermanent;
        }
        
        user = [user copy];
        password = [password copy];
        persistence = persistence;
        hasPassword = (password == nil) ? NO : YES;
        if (persistence == NSURLCredentialPersistencePermanent)
        {
        }
    }
    return self;
}

- (BOOL) isEqual: (id)other
{
    if ((id)self == other)
    {
        return YES;
    }
    if ([other isKindOfClass: [NSURLCredential class]] == NO)
    {
        return NO;
    }
    return [[(NSURLCredential*)other user] isEqualToString: user]
    && [[(NSURLCredential*)other password] isEqualToString: password]
    && [(NSURLCredential*)other persistence] == persistence;
}

- (NSString *) password
{
    return password;
}

- (NSURLCredentialPersistence) persistence
{
    return persistence;
}

- (NSString *) user
{
    return user;
}

@end

