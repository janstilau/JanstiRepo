#import "common.h"

#define	EXPOSE_NSURLCredential_IVARS	1
#import "GSURLPrivate.h"

// Internal data storage
typedef struct {
    NSString			*user;
    NSString			*password;
    NSURLCredentialPersistence	persistence;
    BOOL				hasPassword;
} Internal;

#define	this	((Internal*)(self->_NSURLCredentialInternal))

@implementation	NSURLCredential

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

