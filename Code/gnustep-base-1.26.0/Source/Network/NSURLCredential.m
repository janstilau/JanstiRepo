#import "common.h"

#define	EXPOSE_NSURLCredential_IVARS	1
#import "GSURLPrivate.h"

@implementation	NSURLCredential

// 这个类的内部, 应该会有 type 信息, 来表示不同的验证的机制.
// 这个类, 本身就是一个数据类, 它的使用, 会在网络交互的过程类中. 具体的几乎逻辑, 没有写出
// GNU 的这个类仅仅有着 user, pwd 这种 basic 的验证方式.

/*
 The URL Loading System supports password-based user credentials, certificate-based user credentials, and certificate-based server credentials.
 */

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
    
    if (NSShouldRetainWithZone(self, z) == YES)
    {
        o = RETAIN(self);
    }
    else
    {
        o = [[self class] allocWithZone: z];
        o = [o initWithUser: self->user
                   password: self->password
                persistence: self->persistence];
    }
    return o;
}

- (BOOL) hasPassword
{
    return self->hasPassword;
}

- (NSUInteger) hash
{
    return [self->user hash];
}

- (id) initWithUser: (NSString *)user
           password: (NSString *)password
        persistence: (NSURLCredentialPersistence)persistence
{
    if (user == nil)
    {
        DESTROY(self);
        return nil;
    }
    if ((self = [super init]) != nil)
    {
        if (persistence == NSURLCredentialPersistenceSynchronizable)
        {
            persistence = NSURLCredentialPersistencePermanent;
        }
        
        self->user = [user copy];
        self->password = [password copy];
        self->persistence = persistence;
        self->hasPassword = (self->password == nil) ? NO : YES;
        if (persistence == NSURLCredentialPersistencePermanent)
        {
            // FIXME ... should check to see if we really have a password
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
    return [[(NSURLCredential*)other user] isEqualToString: self->user]
    && [[(NSURLCredential*)other password] isEqualToString: self->password]
    && [(NSURLCredential*)other persistence] == self->persistence;
}

- (NSString *) password
{
    return self->password;
}

- (NSURLCredentialPersistence) persistence
{
    return self->persistence;
}

- (NSString *) user
{
    return self->user;
}

@end

