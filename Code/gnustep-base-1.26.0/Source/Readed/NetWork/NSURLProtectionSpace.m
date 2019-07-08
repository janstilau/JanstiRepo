/* Implementation for NSURLProtectionSpace for GNUstep
 Copyright (C) 2006 Software Foundation, Inc.
 
 Written by:  Richard Frith-Macdonald <rfm@gnu.org>
 Date: 2006
 
 This file is part of the GNUstep Base Library.
 
 This library is free software; you can redistribute it and/or
 modify it under the terms of the GNU Lesser General Public
 License as published by the Free Software Foundation; either
 version 2 of the License, or (at your option) any later version.
 
 This library is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 Library General Public License for more details.
 
 You should have received a copy of the GNU Lesser General Public
 License along with this library; if not, write to the Free
 Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 Boston, MA 02111 USA.
 */

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

+ (id) allocWithZone: (NSZone*)z
{
    NSURLProtectionSpace	*o = [super allocWithZone: z];
    return o;
}

- (NSString *) authenticationMethod
{
    return authenticationMethod;
}

- (NSUInteger) hash
{
    return [[self host] hash] + [self port]
    + [[self realm] hash] + [[self protocol] hash]
    + (uintptr_t)proxyType + (uintptr_t)authenticationMethod;
}

- (NSString *) host
{
    return host;
}

/**
 *
 NSURLAuthenticationMethodDefault
 // 基本的 HTTP 验证，通过 NSURLCredential 对象提供用户名和密码。
 NSURLAuthenticationMethodHTTPBasic
 // 类似于基本的 HTTP 验证，摘要会自动生成，同样通过 NSURLCredential 对象提供用户名和密码。
 NSURLAuthenticationMethodHTTPDigest
 // 不会用于 URL Loading System，在通过 web 表单验证时可能用到。
 NSURLAuthenticationMethodHTMLForm
 NSURLAuthenticationMethodNegotiate
 NSURLAuthenticationMethodNTLM
 // 验证客户端的证书
 NSURLAuthenticationMethodClientCertificate
 // 指明客户端要验证服务端提供的证书
 NSURLAuthenticationMethodServerTrust
 */

- (id) initWithHost: (NSString *)host
               port: (NSInteger)port
           protocol: (NSString *)protocol
              realm: (NSString *)realm
authenticationMethod: (NSString *)authenticationMethod
{
    if ((self = [super init]) != nil)
    {
        host = [host copy];
        protocol = [protocol copy];
        realm = [realm copy];
        if ([authenticationMethod isEqualToString:
             NSURLAuthenticationMethodHTMLForm])
        {
            // The URL loading system never issues authentication challenges based on this authentication method.
            authenticationMethod = NSURLAuthenticationMethodHTMLForm;
        }
        else if ([authenticationMethod isEqualToString:
                  NSURLAuthenticationMethodHTTPBasic])
        { // user password
            authenticationMethod = NSURLAuthenticationMethodHTTPBasic;
        }
        else if ([authenticationMethod isEqualToString:
                  NSURLAuthenticationMethodHTTPDigest] == YES)
        { // like basic ,execpt for add diges
            authenticationMethod = NSURLAuthenticationMethodHTTPDigest;
        }
        else if ([authenticationMethod isEqualToString:
                  NSURLAuthenticationMethodNTLM] == YES)
        {
            authenticationMethod = NSURLAuthenticationMethodNTLM;
        }
        else if ([authenticationMethod isEqualToString:
                  NSURLAuthenticationMethodNegotiate] == YES)
        {
            authenticationMethod = NSURLAuthenticationMethodNegotiate;
        }
        else if ([authenticationMethod isEqualToString:
                  NSURLAuthenticationMethodClientCertificate] == YES)
        {
            authenticationMethod = NSURLAuthenticationMethodClientCertificate;
        }
        else if ([authenticationMethod isEqualToString:
                  NSURLAuthenticationMethodServerTrust] == YES)
        {
            authenticationMethod = NSURLAuthenticationMethodServerTrust;
        }
        else
        {
            authenticationMethod = NSURLAuthenticationMethodDefault;
        }
        port = port;
        proxyType = nil;
        isProxy = NO;
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
        isProxy = YES;
        if ([type isEqualToString: NSURLProtectionSpaceFTPProxy] == YES)
        {
            proxyType = NSURLProtectionSpaceFTPProxy;
        }
        else if ([type isEqualToString: NSURLProtectionSpaceHTTPProxy] == YES)
        {
            proxyType = NSURLProtectionSpaceHTTPProxy;
        }
        else if ([type isEqualToString: NSURLProtectionSpaceHTTPSProxy] == YES)
        {
            proxyType = NSURLProtectionSpaceHTTPSProxy;
        }
        else if ([type isEqualToString: NSURLProtectionSpaceSOCKSProxy] == YES)
        {
            proxyType = NSURLProtectionSpaceSOCKSProxy;
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
    return isProxy;
}

- (NSInteger) port
{
    return port;
}

- (NSString *) protocol
{
    return protocol;
}

- (NSString *) proxyType
{
    return proxyType;
}

- (NSString *) realm
{
    return realm;
}

- (BOOL) receivesCredentialSecurely
{
    if (authenticationMethod == NSURLAuthenticationMethodHTTPDigest)
    {
        return YES;
    }
    if (isProxy)
    {
        if (proxyType == NSURLProtectionSpaceHTTPSProxy)
        {
            return YES;
        }
    }
    else
    {
        if ([protocol isEqual: @"https"] == YES)
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

