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

/*
 
 这里有问题, 居然没有 SecTrustRef 的构造函数.
 */

+ (id) allocWithZone: (NSZone*)z
{
  NSURLCredential	*o = [super allocWithZone: z];

  if (o != nil)
    {
      o->_NSURLCredentialInternal = NSZoneCalloc(z, 1, sizeof(Internal));
    }
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
      o = [o initWithUser: this->user
		 password: this->password
	      persistence: this->persistence];
    }
  return o;
}

- (void) dealloc
{
  if (this != 0)
    {
      RELEASE(this->user);
      RELEASE(this->password);
      NSZoneFree([self zone], this);
    }
  [super dealloc];
}

- (BOOL) hasPassword
{
  return this->hasPassword;
}

- (NSUInteger) hash
{
  return [this->user hash];
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
	  persistence = NSURLCredentialPersistencePermanent; // NSURLCredentialPersistenceSynchronizable 是和 Permanent 一致的.
	}
      
      this->user = [user copy];
      this->password = [password copy];
      this->persistence = persistence;
      this->hasPassword = (this->password == nil) ? NO : YES;
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
  return [[(NSURLCredential*)other user] isEqualToString: this->user]
    && [[(NSURLCredential*)other password] isEqualToString: this->password]
    && [(NSURLCredential*)other persistence] == this->persistence;
}

- (NSString *) password
{
  return this->password;
}

- (NSURLCredentialPersistence) persistence
{
  return this->persistence;
}

- (NSString *) user
{
  return this->user;
}

@end

