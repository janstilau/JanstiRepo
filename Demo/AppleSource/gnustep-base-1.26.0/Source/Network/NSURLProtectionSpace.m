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

@implementation NSURLProtectionSpace

- (NSString *) authenticationMethod
{
    return self->authenticationMethod;
}

- (NSUInteger) hash
{
    return [[self host] hash]
    + [self port]
    + [[self realm] hash]
    + [[self protocol] hash]
    + (uintptr_t)self->proxyType
    + (uintptr_t)self->authenticationMethod;
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
    
@end
    
