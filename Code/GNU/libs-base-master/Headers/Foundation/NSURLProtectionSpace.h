#ifndef __NSURLProtectionSpace_h_GNUSTEP_BASE_INCLUDE
#define __NSURLProtectionSpace_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_2,GS_API_LATEST) && GS_API_VERSION( 11300,GS_API_LATEST)

#import	<Foundation/NSObject.h>

#if	defined(__cplusplus)
extern "C" {
#endif

@class NSString;

/*
 SURLProtectionSpaceHTTP // http协议
 NSURLProtectionSpaceHTTPS // https协议
 NSURLProtectionSpaceFTP // ftp协议
 NSURLProtectionSpaceHTTPProxy // http代理
 NSURLProtectionSpaceHTTPSProxy // https代理
 NSURLProtectionSpaceFTPProxy // ftp代理
 NSURLProtectionSpaceSOCKSProxy // socks代理
 NSURLAuthenticationMethodDefault // 协议的默认身份认证
 NSURLAuthenticationMethodHTTPBasic // http的basic认证,等同于NSURLAuthenticationMethodDefault
 NSURLAuthenticationMethodHTTPDigest // http的摘要认证
 NSURLAuthenticationMethodHTMLForm // html的表单认证
 适用于任何协议
 NSURLAuthenticationMethodNTLM // NTLM认证
 NSURLAuthenticationMethodNegotiate // Negotiate认证
 NSURLAuthenticationMethodClientCertificate // ssl证书认证,适用于任何协议
 NSURLAuthenticationMethodServerTrust // ServerTrust认证,适用于任何协议
 */

extern NSString * const NSURLProtectionSpaceFTPProxy;	/** An FTP proxy */
extern NSString * const NSURLProtectionSpaceHTTPProxy;	/** An HTTP proxy */
extern NSString * const NSURLProtectionSpaceHTTPSProxy;	/** An HTTPS proxy */
extern NSString * const NSURLProtectionSpaceSOCKSProxy;	/** A SOCKS proxy */

// 各种认证的方式.
/** Default authentication (Basic) */
extern NSString * const NSURLAuthenticationMethodDefault;

/** HTML form authentication */
extern NSString * const NSURLAuthenticationMethodHTMLForm;

/** HTTP Basic authentication */
extern NSString * const NSURLAuthenticationMethodHTTPBasic; // 用户提供用户名密码

/** HTTP Digest authentication */
extern NSString * const NSURLAuthenticationMethodHTTPDigest;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_5,GS_API_LATEST) && GS_API_VERSION( 11300,GS_API_LATEST)
extern NSString * const NSURLAuthenticationMethodNTLM;
extern NSString * const NSURLAuthenticationMethodNegotiate;
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_6,GS_API_LATEST) && GS_API_VERSION( 11300,GS_API_LATEST)
extern NSString * const NSURLAuthenticationMethodClientCertificate;
extern NSString * const NSURLAuthenticationMethodServerTrust;
#endif

/*
 * Class to encapsulate a protection space ... where authentication is
 * required.
 */
// 这个类, 用来表示, protocol: host/realm: port , 需要使用哪种 authenticationMethod 方式进行认证.
//
@interface NSURLProtectionSpace : NSObject <NSCopying>
{
    NSString    *host;
    int         port;
    NSString    *protocol;
    NSString    *realm;
    NSString    *proxyType;        // Not retained
    NSString    *authenticationMethod;    // Not retained
    BOOL        isProxy;
}

/**
 * Returns the authentication method used for this protection space.
 */
- (NSString *) authenticationMethod;

/**
 * Returns the host (or proxy host) set in the receiver.
 */
- (NSString *) host;

/**
 * Initialises the receiver with host, port, and protocol identifying the
 * protection space.  For some protocols the realm identifies a space
 * within the host, for others it may be nil.
 */
- (id) initWithHost: (NSString *)host
               port: (NSInteger)port
           protocol: (NSString *)protocol
              realm: (NSString *)realm
authenticationMethod: (NSString *)authenticationMethod;

/**
 * This is like -initWithHost:port:protocol:realm:authenticationMethod:
 * except that it uses a proxy host and proxy type rather than an actual
 * host and a protocol.
 */
- (id) initWithProxyHost: (NSString *)host
                    port: (NSInteger)port
                    type: (NSString *)type
                   realm: (NSString *)realm
    authenticationMethod: (NSString *)authenticationMethod;

/**
 * Returns a flag to indicate whether this protection space is on a proxy
 * server or not.
 */
- (BOOL) isProxy;

/**
 * Returns the port set for this receiver or zero if none was set.
 */
- (NSInteger) port;

/**
 * Returns the protocol of the receiver or nil if it is a proxy.
 */
- (NSString *) protocol;

/**
 * Returns the proxy type set for the receiver or nil if it's not a proxy.
 */
- (NSString *) proxyType;

/**
 * Returns the realm (or nil) which was set in the receiver upon initialisation.
 */
- (NSString *) realm;

/**
 * Returns a flag to indicate whether the password for this protection space
 * will be sent over a secure mechanism.
 */
- (BOOL) receivesCredentialSecurely;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_6,GS_API_LATEST) && GS_API_VERSION( 11300,GS_API_LATEST)
#if GS_HAS_DECLARED_PROPERTIES
@property (readonly, copy) NSArray *distinguishedNames;
#else
- (NSArray *) distinguishedNames;
#endif
#endif

@end

#if	defined(__cplusplus)
}
#endif

#endif

#endif
