#import "common.h"

#define	EXPOSE_NSURLProtectionSpace_IVARS	1
#import "GSURLPrivate.h"
#import "GNUstepBase/NSURL+GNUstepBase.h"

NSString * const NSURLProtectionSpaceFTPProxy = @"ftp";	
NSString * const NSURLProtectionSpaceHTTPProxy = @"http";
NSString * const NSURLProtectionSpaceHTTPSProxy = @"https";
NSString * const NSURLProtectionSpaceSOCKSProxy = @"SOCKS";

NSString * const NSURLAuthenticationMethodHTTPBasic // 基础认证, basic
= @"NSURLAuthenticationMethodHTTPBasic";
NSString * const NSURLAuthenticationMethodHTTPDigest // 摘要认证, digest.
= @"NSURLAuthenticationMethodHTTPDigest";


// 下面这四种, 不会出现在 iOS 的URL Loading System 里面, 只会出现在
NSString * const NSURLAuthenticationMethodNTLM
= @"NSURLAuthenticationMethodNTLM";
NSString * const NSURLAuthenticationMethodDefault
= @"NSURLAuthenticationMethodDefault";
NSString * const NSURLAuthenticationMethodHTMLForm
= @"NSURLAuthenticationMethodHTMLForm";
NSString * const NSURLAuthenticationMethodNegotiate
= @"NSURLAuthenticationMethodNegotiate";

NSString * const NSURLAuthenticationMethodClientCertificate // 要求验证客户端的证书.
= @"NSURLAuthenticationMethodClientCertificate";
NSString * const NSURLAuthenticationMethodServerTrust //要求客户端验证服务器端公钥.
= @"NSURLAuthenticationMethodServerTrust";

// Unlike other challenges where the server is asking your app to authenticate itself, this is an opportunity for you to authenticate the server’s credentials.
// 也就是说, 其他的 Authentication 都是要求客户端提供某些验证的消息, 这个类型是客户端验证服务器端的证书.
/*
 大部分情况下, 使用默认的处理就可以了. 如果代理不实现代理方法, 就是系统就会使用默认处理. 默认处理就是, 如果使用的是认证过的证书, 系统就会自动处理.
 如果:
 1. 想要使用自定义的证书, 自定义的证书系统不会识别, 所以必须要通过代理方法来使用这个证书.
 
 这里如何验证, 在官方文档里面写了详细的说明. 首先, 在包内部, 要存储一个 public key, 用这个 public key 要和传递过来的 key 进行比较, 然后, 要进行一下这个 public key 签名比较. 这个签名比较就有各种方式的比较了. 因为自定义的证书, 并没有说有签发机构的私钥加密, 客户端公钥紧密的机会. 所以, 其实可以自定义一套加盐加密算法, 用这套加盐加密的算法得到的值当做签名. 而这套加盐加密直接内嵌到客户端里面就可以了.
 
 * The challenge type is server trust, and not some other kind of challenge
 * The challenge’s host name matches the host that you want to perform manual credential evaluation for.
 
 2. 如果想要拒绝某些系统是别的证书, 因为想要进行管理.
 
 Determine When Manual Server Trust Evaluation Is Appropriate
 */

/*
 WWW-Authenticate:  Basic realm="Secure Area"
 这里, 首先的第一个单词, 是认证的方法. 例如, basic 就是账号密码这种方式.
 realm 是展示给用户的, 通常是所访问的计算机或系统的描述
 用户输入了用户名和口令后，客户端软件会在原先的请求上增加认证消息头（值是base64encode(username+":"+password)），然后重新发送再次尝试。
 服务器接受了该认证屏幕并返回了页面。如果用户凭据非法或无效，服务器可能再次返回401应答码，客户端可以再次提示用户输入口令。 所以, 这个东西可能会多次发生.
 
 还有一种, 是 http 摘要认证.
 它在密码发出前，先对其应用哈希函数，这相对于HTTP基本认证发送明文而言，更安全。
 WWW-Authenticate: Digest realm="testrealm@host.com", qop="auth,auth-int", nonce="dcd98b7102dd2f0e8b11d0f600bfb0c093", opaque="5ccc069c403ebaf9f0171e9517f40e41"
 Authorization: Digest username="Mufasa",
 realm="testrealm@host.com",
 nonce="dcd98b7102dd2f0e8b11d0f600bfb0c093",
 uri="/dir/index.html",
 qop=auth,
 nc=00000001,
 cnonce="0a4f113b",
 response="6629fae49393a05397450978507c4ef1",
 opaque="5ccc069c403ebaf9f0171e9517f40e41"
 */

// Internal data storage
typedef struct {
    NSString	*host; // 域名
    int		port; // 端口号
    NSString	*protocol; // 协议
    NSString	*realm; // realm, 在 web 里面一般用于提示信息.
    NSString	*proxyType;		// Not retained
    NSString	*authenticationMethod;	// 认证方法, 是 basic, digest 还是什么
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

- (int) hash
{
    return [[self host] hash] + [self port]
    + [[self realm] hash] + [[self protocol] hash]
    + (uintptr_t)this->proxyType + (uintptr_t)this->authenticationMethod; // hash 用到了自身的各种成员变量.
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
        this->host = [host copy]; // 记录 host
        this->protocol = [protocol copy]; // 记录 协议
        this->realm = [realm copy]; // 记录 realm
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

