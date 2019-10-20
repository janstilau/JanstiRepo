#import "common.h"

#define	EXPOSE_NSURLProtectionSpace_IVARS	1
#import "GSURLPrivate.h"
#import "GNUstepBase/NSURL+GNUstepBase.h"

NSString * const NSURLProtectionSpaceFTPProxy = @"ftp";	
NSString * const NSURLProtectionSpaceHTTPProxy = @"http";
NSString * const NSURLProtectionSpaceHTTPSProxy = @"https";
NSString * const NSURLProtectionSpaceSOCKSProxy = @"SOCKS";
NSString * const NSURLAuthenticationMethodDefault
  = @"NSURLAuthenticationMethodDefault";
NSString * const NSURLAuthenticationMethodHTMLForm
  = @"NSURLAuthenticationMethodHTMLForm";
NSString * const NSURLAuthenticationMethodHTTPBasic
  = @"NSURLAuthenticationMethodHTTPBasic";
NSString * const NSURLAuthenticationMethodHTTPDigest
  = @"NSURLAuthenticationMethodHTTPDigest";

NSString * const NSURLAuthenticationMethodNTLM
  = @"NSURLAuthenticationMethodNTLM";

NSString * const NSURLAuthenticationMethodNegotiate
  = @"NSURLAuthenticationMethodNegotiate";
NSString * const NSURLAuthenticationMethodClientCertificate
  = @"NSURLAuthenticationMethodClientCertificate";
NSString * const NSURLAuthenticationMethodServerTrust
  = @"NSURLAuthenticationMethodServerTrust";

// Internal data storage
typedef struct {
  NSString	*host;
  int		port;
  NSString	*protocol;
  NSString	*realm;
  NSString	*proxyType;		// Not retained
  NSString	*authenticationMethod;	// Not retained
  BOOL		isProxy;
} Internal;
 
#define	this	((Internal*)(self->_NSURLProtectionSpaceInternal))
#define	inst	((Internal*)(o->_NSURLProtectionSpaceInternal))

@implementation NSURLProtectionSpace

+ (id) allocWithZone: (NSZone*)z
{
  NSURLProtectionSpace	*o = [super allocWithZone: z];

  if (o != nil)
    {
      o->_NSURLProtectionSpaceInternal = NSZoneCalloc(z, 1, sizeof(Internal));
    }
  return o;
}

- (NSString *) authenticationMethod
{
  return this->authenticationMethod;
}

- (id) copyWithZone: (NSZone*)z
{
  if (NSShouldRetainWithZone(self, z) == YES)
    {
      return RETAIN(self);
    }
  else
    {
      NSURLProtectionSpace	*o = [[self class] allocWithZone: z];

      o = [o initWithHost: this->host
		     port: this->port
		 protocol: this->protocol
		    realm: this->realm
     authenticationMethod: this->authenticationMethod];
      if (o != nil)
	{
	  inst->isProxy = this->isProxy;
	  inst->proxyType = this->proxyType;
	}
      return o;
    }
}

- (void) dealloc
{
  if (this != 0)
    {
      RELEASE(this->host);
      RELEASE(this->protocol);
      RELEASE(this->realm);
      NSZoneFree([self zone], this);
    }
  [super dealloc];
}

- (NSUInteger) hash
{
  return [[self host] hash] + [self port]
    + [[self realm] hash] + [[self protocol] hash]
    + (uintptr_t)this->proxyType + (uintptr_t)this->authenticationMethod;
}

- (NSString *) host
{
  return this->host;
}

- (id) initWithHost: (NSString *)host
	       port: (NSInteger)port
	   protocol: (NSString *)protocol
	      realm: (NSString *)realm
authenticationMethod: (NSString *)authenticationMethod
{
  if ((self = [super init]) != nil)
    {
      this->host = [host copy];
      this->protocol = [protocol copy];
      this->realm = [realm copy];
      if ([authenticationMethod isEqualToString: 
	NSURLAuthenticationMethodHTMLForm] == YES)
	{
	  this->authenticationMethod = NSURLAuthenticationMethodHTMLForm;
	}
      else if ([authenticationMethod isEqualToString: 
	NSURLAuthenticationMethodHTTPBasic] == YES)
	{
	  this->authenticationMethod = NSURLAuthenticationMethodHTTPBasic;
	}
      else if ([authenticationMethod isEqualToString: 
	NSURLAuthenticationMethodHTTPDigest] == YES)
	{
	  this->authenticationMethod = NSURLAuthenticationMethodHTTPDigest;
	}
      else if ([authenticationMethod isEqualToString: 
	NSURLAuthenticationMethodNTLM] == YES)
	{
	  this->authenticationMethod = NSURLAuthenticationMethodNTLM;
	}
      else if ([authenticationMethod isEqualToString: 
	NSURLAuthenticationMethodNegotiate] == YES)
	{
	  this->authenticationMethod = NSURLAuthenticationMethodNegotiate;
	}
      else if ([authenticationMethod isEqualToString: 
	NSURLAuthenticationMethodClientCertificate] == YES)
	{
	  this->authenticationMethod = NSURLAuthenticationMethodClientCertificate;
	}
      else if ([authenticationMethod isEqualToString: 
	NSURLAuthenticationMethodServerTrust] == YES)
	{
	  this->authenticationMethod = NSURLAuthenticationMethodServerTrust;
	}
      else
        {
	  this->authenticationMethod = NSURLAuthenticationMethodDefault;
	}
      this->port = port;
      this->proxyType = nil;
      this->isProxy = NO;
    }
  return self;
}

- (id) initWithProxyHost: (NSString *)host
		    port: (NSInteger)port
		    type: (NSString *)type
		   realm: (NSString *)realm
    authenticationMethod: (NSString *)authenticationMethod
{
  self = [self initWithHost: host
		       port: port
		   protocol: nil
		      realm: realm
       authenticationMethod: authenticationMethod];
  if (self != nil)
    {
      this->isProxy = YES;
      if ([type isEqualToString: NSURLProtectionSpaceFTPProxy] == YES)
        {
	  this->proxyType = NSURLProtectionSpaceFTPProxy;
	}
      else if ([type isEqualToString: NSURLProtectionSpaceHTTPProxy] == YES)
        {
	  this->proxyType = NSURLProtectionSpaceHTTPProxy;
	}
      else if ([type isEqualToString: NSURLProtectionSpaceHTTPSProxy] == YES)
        {
	  this->proxyType = NSURLProtectionSpaceHTTPSProxy;
	}
      else if ([type isEqualToString: NSURLProtectionSpaceSOCKSProxy] == YES)
        {
	  this->proxyType = NSURLProtectionSpaceSOCKSProxy;
	}
      else
        {
	  DESTROY(self);	// Bad proxy type.
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
  if ([other isKindOfClass: [NSURLProtectionSpace class]] == NO)
    {
      return NO;
    }
  else
    {
      NSURLProtectionSpace	*o = (NSURLProtectionSpace*)other;

      if ([[self host] isEqual: [o host]] == NO)
        {
	  return NO;
	}
      if ([[self realm] isEqual: [o realm]] == NO)
        {
	  return NO;
	}
      if ([self port] != [o port])
        {
	  return NO;
	}
      if ([[self authenticationMethod] isEqual: [o authenticationMethod]] == NO)
        {
	  return NO;
	}
      if ([self isProxy] == YES)
        {
          if ([o isProxy] == NO
	    || [[self proxyType] isEqual: [o proxyType]] == NO)
	    {
	      return NO;
	    }
	}
      else
        {
          if ([o isProxy] == YES
	    || [[self protocol] isEqual: [o protocol]] == NO)
	    {
	      return NO;
	    }
	}
      return YES;
    }
}

- (BOOL) isProxy
{
  return this->isProxy;
}

- (NSInteger) port
{
  return this->port;
}

- (NSString *) protocol
{
  return this->protocol;
}

- (NSString *) proxyType
{
  return this->proxyType;
}

- (NSString *) realm
{
  return this->realm;
}

- (BOOL) receivesCredentialSecurely
{
  if (this->authenticationMethod == NSURLAuthenticationMethodHTTPDigest)
    {
      return YES;
    }
  if (this->isProxy)
    {
      if (this->proxyType == NSURLProtectionSpaceHTTPSProxy)
        {
	  return YES;
	}
    }
  else
    {
      if ([this->protocol isEqual: @"https"] == YES)
        {
	  return YES;
	}
    }
  return NO;
}

- (NSArray *) distinguishedNames
{
  return nil;
}

@end

