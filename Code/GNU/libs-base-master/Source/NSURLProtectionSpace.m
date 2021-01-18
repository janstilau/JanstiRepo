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

#define	self	((Internal*)(self->_NSURLProtectionSpaceInternal))
#define	inst	((Internal*)(o->_NSURLProtectionSpaceInternal))

@implementation NSURLProtectionSpace

- (NSString *) authenticationMethod
{
    return self->authenticationMethod;
}

// 各种数据加载一起, 进行最终的 hash.
- (NSUInteger) hash
{
    return [[self host] hash] + [self port]
    + [[self realm] hash] + [[self protocol] hash]
    + (uintptr_t)self->proxyType + (uintptr_t)self->authenticationMethod;
}

- (NSString *) host
{
    return self->host;
}

- (id) initWithHost: (NSString *)host
               port: (NSInteger)port
           protocol: (NSString *)protocol
              realm: (NSString *)realm
authenticationMethod: (NSString *)authenticationMethod
{
    if ((self = [super init]) != nil)
    {
        self->host = [host copy];
        self->protocol = [protocol copy];
        self->realm = [realm copy];
        if ([authenticationMethod isEqualToString:
             NSURLAuthenticationMethodHTMLForm] == YES)
        {
            self->authenticationMethod = NSURLAuthenticationMethodHTMLForm;
        }
        else if ([authenticationMethod isEqualToString:
                  NSURLAuthenticationMethodHTTPBasic] == YES)
        {
            self->authenticationMethod = NSURLAuthenticationMethodHTTPBasic;
        }
        else if ([authenticationMethod isEqualToString:
                  NSURLAuthenticationMethodHTTPDigest] == YES)
        {
            self->authenticationMethod = NSURLAuthenticationMethodHTTPDigest;
        }
        else if ([authenticationMethod isEqualToString:
                  NSURLAuthenticationMethodNTLM] == YES)
        {
            self->authenticationMethod = NSURLAuthenticationMethodNTLM;
        }
        else if ([authenticationMethod isEqualToString:
                  NSURLAuthenticationMethodNegotiate] == YES)
        {
            self->authenticationMethod = NSURLAuthenticationMethodNegotiate;
        }
        else if ([authenticationMethod isEqualToString:
                  NSURLAuthenticationMethodClientCertificate] == YES)
        {
            self->authenticationMethod = NSURLAuthenticationMethodClientCertificate;
        }
        else if ([authenticationMethod isEqualToString:
                  NSURLAuthenticationMethodServerTrust] == YES)
        {
            self->authenticationMethod = NSURLAuthenticationMethodServerTrust;
        }
        else
        {
            self->authenticationMethod = NSURLAuthenticationMethodDefault;
        }
        self->port = port;
        self->proxyType = nil;
        self->isProxy = NO;
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
        self->isProxy = YES;
        if ([type isEqualToString: NSURLProtectionSpaceFTPProxy] == YES)
        {
            self->proxyType = NSURLProtectionSpaceFTPProxy;
        }
        else if ([type isEqualToString: NSURLProtectionSpaceHTTPProxy] == YES)
        {
            self->proxyType = NSURLProtectionSpaceHTTPProxy;
        }
        else if ([type isEqualToString: NSURLProtectionSpaceHTTPSProxy] == YES)
        {
            self->proxyType = NSURLProtectionSpaceHTTPSProxy;
        }
        else if ([type isEqualToString: NSURLProtectionSpaceSOCKSProxy] == YES)
        {
            self->proxyType = NSURLProtectionSpaceSOCKSProxy;
        }
        else
        {
            DESTROY(self);	// Bad proxy type.
        }
    }
    return self;
}

- (BOOL) isProxy
{
    return self->isProxy;
}

- (NSInteger) port
{
    return self->port;
}

- (NSString *) protocol
{
    return self->protocol;
}

- (NSString *) proxyType
{
    return self->proxyType;
}

- (NSString *) realm
{
    return self->realm;
}

- (BOOL) receivesCredentialSecurely
{
    if (self->authenticationMethod == NSURLAuthenticationMethodHTTPDigest)
    {
        return YES;
    }
    if (self->isProxy)
    {
        if (self->proxyType == NSURLProtectionSpaceHTTPSProxy)
        {
            return YES;
        }
    }
    else
    {
        if ([self->protocol isEqual: @"https"] == YES)
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

