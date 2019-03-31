//
//  MCNetwork.m
//  MCMoego
//
//  Created by Zhou Kang on 2017/10/11.
//  Copyright © 2017年 Moca Inc. All rights reserved.
//

#import "MCNetwork.h"
#import "MCEncryptor.h"
#import <CoreTelephony/CTCarrier.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import "UIDevice+FCUUID.h"
#import "CoreLoginUser+MCExtension.h"
#import "MCJWT.h"
#import "MCEarnCoinView.h"
#import <AdSupport/AdSupport.h>

#define SYSTEM_TIME_DIFF @"SYSTEM_TIME_DIFF"

static NSMutableDictionary *AESKeysDict_;

@implementation HTTPResponse

- (NSDictionary *)dataDict {
    if (![self.payload isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    id data = self.payload[@"data"];
    if ([data isKindOfClass:[NSArray class]]) {
        NSDictionary *newDataDict = @{ @"list": data };
        return newDataDict;
    }
    if (![data isKindOfClass:[NSDictionary class]]) {
        return [NSDictionary dictionary];
    }
    return data;
}

@end

// ------

@implementation UGJSONResponseSerializer

- (id)responseObjectForResponse:(NSURLResponse *)response
                           data:(NSData *)data
                          error:(NSError *__autoreleasing  _Nullable *)error {
    id responseObject = [super responseObjectForResponse:response data:data error:error];
    if (!responseObject && *error && data && [data length]) {
        responseObject = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    return responseObject;
}

@end

// ------

@interface MCNetwork ()

@property (nonatomic, strong) Reachability *reachability;
@property (nonatomic, strong) NSMutableArray <void(^)(NetworkStatus status)> *netChanggeCallbacks;

@end

@implementation MCNetwork

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setup];
        [self loadParamEncryptConfigure];
        AESKeysDict_ = [NSMutableDictionary dictionary];
        _netChanggeCallbacks = [NSMutableArray array];
    }
    return self;
}

+ (instancetype)defaultManager {
    static dispatch_once_t pred = 0;
    __strong static id defaultMCNetwork = nil;
    dispatch_once( &pred, ^{
        defaultMCNetwork = [[self alloc] init];
    });
    
    return defaultMCNetwork;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setup {
    UGJSONResponseSerializer *responseSerializer = [UGJSONResponseSerializer serializer];
    responseSerializer.acceptableContentTypes = nil;
    responseSerializer.removesKeysWithNullValues = NO;
    
    NSURL *baseURL = [NSURL URLWithString:INIT_DOMAIN];
    _sessionManager = [[AFHTTPSessionManager alloc] initWithBaseURL:baseURL];
    _sessionManager.responseSerializer = responseSerializer;
    
    NSURLCache *urlCache = [NSURLCache sharedURLCache];
    [urlCache setMemoryCapacity:50 * 1024 * 1024];
    [urlCache setDiskCapacity:200 * 1024 * 1024];
    [NSURLCache setSharedURLCache:urlCache];
    
    _reachability = [Reachability reachabilityForInternetConnection];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reachabilityChanged:)
                                                 name:kReachabilityChangedNotification
                                               object:nil];
    [_reachability startNotifier];
}

- (void)loadParamEncryptConfigure {
    NSNumber *encryptEnable = [userDefaults objectForKey:UserDefaultKey_Net_Encrypt];
    if (!encryptEnable) {
        encryptEnable = @(YES);
        [userDefaults setObject:encryptEnable forKey:UserDefaultKey_Net_Encrypt];
    }
    _encryptEnable = [encryptEnable boolValue];
}

- (void)addNetStatusChangeCallback:(void (^)(NetworkStatus))callback {
    [_netChanggeCallbacks addObject:callback];
}

- (void)reachabilityChanged:(NSNotification *)noti {
    NetworkStatus status = _reachability.currentReachabilityStatus;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *statusStr = nil;
        switch (status) {
            case NotReachable:{
                statusStr = @"Network Not Reachable";
            } break;
            case ReachableViaWWAN:{
                statusStr = @"Network Reachs To WWAN";
            } break;
            case ReachableViaWiFi:{
                statusStr = @"Network Reachs To WIFI";
            } break;
        }
        // [MCToast showMessage:statusStr];
        DLOG(@"%@", statusStr);
        [self.netChanggeCallbacks enumerateObjectsUsingBlock:^(void (^ _Nonnull obj)(NetworkStatus), NSUInteger idx, BOOL * _Nonnull stop) {
            obj(status);
        }];
    });
}

- (NetworkStatus)networkStatus {
    return _reachability.currentReachabilityStatus;
}

- (NSURLSessionDataTask *)putRequestToUrl:(NSString *)url
                                   params:(NSDictionary *)params
                                 complete:(HTTPTaskCompleteHandler)complete {
    return [self requestToUrl:url
                       method:@"PUT"
                     useCache:NO
                       params:params
                      request:nil
                     complete:complete];
}

- (NSURLSessionDataTask *)deleteRequestToUrl:(NSString *)url params:(NSDictionary *)params complete:(HTTPTaskCompleteHandler)complete {
    return [self requestToUrl:url
                       method:@"DELETE"
                     useCache:NO
                       params:params
                      request:nil
                     complete:complete];
}

- (NSURLSessionDataTask *)getRequestToUrl:(NSString *)url
                                   params:(NSDictionary *)params
                                 complete:(HTTPTaskCompleteHandler)complete {
    return [self getRequestToUrl:url
                          params:params
                         request:nil
                        complete:complete];
}

- (NSURLSessionDataTask *)getRequestToUrl:(NSString *)url
                                   params:(NSDictionary *)params
                                  request:(HTTPTaskRequestHandler)requestHandler
                                 complete:(HTTPTaskCompleteHandler)complete {
    return [self requestToUrl:url
                       method:@"GET"
                     useCache:NO
                       params:params
                      request:requestHandler
                     complete:complete];
}

- (NSURLSessionDataTask *)getCacheToUrl:(NSString *)url
                                 params:(NSDictionary *)params
                               complete:(HTTPTaskCompleteHandler)complete {
    return [self getCacheToUrl:url
                        params:params
                       request:nil
                      complete:complete];
}

- (NSURLSessionDataTask *)getCacheToUrl:(NSString *)url
                                 params:(NSDictionary *)params
                                request:(HTTPTaskRequestHandler)requestHandler
                               complete:(HTTPTaskCompleteHandler)complete {
    return [self requestToUrl:url
                       method:@"GET"
                     useCache:YES
                       params:params
                      request:requestHandler
                     complete:complete];
}

- (NSURLSessionDataTask *)postRequestToUrl:(NSString *)url
                                    params:(NSDictionary *)params
                                  complete:(HTTPTaskCompleteHandler)complete {
    return [self postRequestToUrl:url
                           params:params
                          request:nil
                         complete:complete];
}

- (NSURLSessionDataTask *)postRequestToUrl:(NSString *)url
                                    params:(NSDictionary *)params
                                   request:(HTTPTaskRequestHandler)requestHandler
                                  complete:(HTTPTaskCompleteHandler)complete {
    return [self requestToUrl:url
                       method:@"POST"
                     useCache:NO
                       params:params
                      request:requestHandler
                     complete:complete];
}

- (NSURLSessionDataTask *)postCacheToUrl:(NSString *)url
                                  params:(NSDictionary *)params
                                complete:(HTTPTaskCompleteHandler)complete {
    return [self postCacheToUrl:url
                         params:params
                        request:nil
                       complete:complete];
}

- (NSURLSessionDataTask *)postCacheToUrl:(NSString *)url
                                  params:(NSDictionary *)params
                                 request:(HTTPTaskRequestHandler)requestHandler
                                complete:(HTTPTaskCompleteHandler)complete {
    return [self requestToUrl:url
                       method:@"POST"
                     useCache:YES
                       params:params
                      request:requestHandler
                     complete:complete];
}

- (NSURLSessionDataTask *)requestToUrl:(NSString *)url
                                method:(NSString *)method
                              useCache:(BOOL)useCache
                                params:(NSDictionary *)params
                               request:(HTTPTaskRequestHandler)requestHandler
                              complete:(HTTPTaskCompleteHandler)completeHandler {
    if (NetWork.networkStatus == NotReachable && !useCache) {
        [MCToast showMessage:MCNetworkMessageNotReachable];
        !completeHandler ?: completeHandler(false, nil);
        return nil;
    }
    
    if (!NetWorkJWTEnabled) {
        url = [url stringByAppendingString:@"?__debug__=1"];
    }
    NSMutableURLRequest *request = [self requestWithUrl:url method:method shouldAutoFillBody:true params:params];
    if (requestHandler) {
        requestHandler(request);
    }
    [self fillHeaderFileds:request];
    
    NSURLSessionDataTask *dataTask = nil;
    void (^completionHandler)(NSURLResponse *, id, NSError *) = ^(NSURLResponse *response, id responseObject, NSError *error) {
        [self logInfoWithRequest:request method:method res:responseObject];
        
        HTTPResponse *resObj = [[HTTPResponse alloc] init];
        resObj.requestURL = request.URL;
        resObj.requestParams = [request.accessibilityValue ug_object]?:params;
        resObj.error = error;
        
        if (error) {
            NSLog(@"%@ error :  %@",[method lowercaseString],error);
            !completeHandler ?: completeHandler(false, resObj);
            [self handleHttpResponseError:error useCache:useCache];
        }
        else {
            [self takesTimeWithRequest:request flag:@"接口"];
            [self dictionaryWithData:responseObject complete:^(NSDictionary *object) {
                resObj.payload = object;
                NSString *flagStr = response.accessibilityValue;
                if (flagStr && [flagStr isEqualToString:@"cache_data"]) {
                    resObj.isCache = YES;
                }
                [self handleResponse:resObj complete:completeHandler];
            }];
        }
    };
    if (useCache) {
        NSURLRequest *cacheRequest = [self cacheRequestUrl:url method:@"GET" params:params];
        dataTask = [self cacheDataTaskWithRequest:request cacheRequest:cacheRequest completionHandler:completionHandler];
    }
    else {
        dataTask = [_sessionManager dataTaskWithRequest:request uploadProgress:nil downloadProgress:nil completionHandler:completionHandler];
    }
    [dataTask resume];
    return dataTask;
}

- (void)fillHeaderFileds:(NSMutableURLRequest *)request {
    UIDevice *device = [UIDevice currentDevice];
    
    NSDictionary *params = @{ @"o": safeStr(device.systemName),
                              @"s": safeStr(@(NSFoundationVersionNumber).stringValue),
                              @"sv": safeStr(device.systemVersion),
                              @"a": XcodeVersionCode,
                              @"n": XcodeAppVersion,
                              @"ad": safeStr(device.uuid),
                              @"w": @(kScreenWidth).stringValue,
                              @"h": @(kScreenHeight).stringValue,
                              @"c": @"AppStore",
                              @"lang": @"zh-Hans",
                              @"m": safeStr(device.model),
                              };
    [request setAllHTTPHeaderFields:params];
}

- (NSMutableURLRequest *)requestWithUrl:(NSString *)url
                                 method:(NSString *)method
                     shouldAutoFillBody:(BOOL)shouldAutoFillBody
                                 params:(NSDictionary *)params {
    [self detectProxy];
    NSMutableDictionary *requestParams = params.mutableCopy ?: [NSMutableDictionary dictionary];
    NSURL *requestURL = [NSURL URLWithString:url];
    // DLOG(@"%@请求的原始业务参数：%@ ", requestURL.path, [params sortedStr]);
    BOOL needVerify = [[self class] isNeedVerifyForUrl:url];
    if (needVerify && shouldAutoFillBody) {
        requestParams = [[self class] getRequestBodyWithParams:params URL:requestURL isCache:false];
    }
    
    AFHTTPRequestSerializer *serializer = [AFHTTPRequestSerializer serializer];
    
    // 为了兼容萌股后端PUT不能接收Body体中的参数, 所以手动拼到URL后
    if ([[method uppercaseString] isEqualToString:@"PUT"]) {
        if ([url containsString:@"__debug__"]) {
            url = [NSString stringWithFormat:@"%@&%@", url, [requestParams mc_sortedEncodedQueryStr]];
        }
        else {
            url = [NSString stringWithFormat:@"%@?%@", url, [requestParams mc_sortedEncodedQueryStr]];
        }
        requestParams = nil;
    }
    
    NSMutableURLRequest *request = [serializer requestWithMethod:method URLString:url parameters:requestParams error:nil];
    request.accessibilityValue = [requestParams ug_json];
    request.accessibilityHint = [@([[NSDate date] timeIntervalSince1970]) stringValue];
    [request setTimeoutInterval:20];
    [request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
    
    if(needVerify){
        [self setCookieForRequest:request];
    }
    return request;
}

- (void)detectProxy {
#if DEBUG
    NSDictionary *proxySettings = (__bridge NSDictionary *)(CFNetworkCopySystemProxySettings());
    NSArray *proxies = (__bridge NSArray *)(CFNetworkCopyProxiesForURL((__bridge CFURLRef _Nonnull)([NSURL URLWithString:@"https://www.baidu.com"]), (__bridge CFDictionaryRef _Nonnull)(proxySettings)));
    NSDictionary *settings = proxies[0];
    if (![[settings objectForKey:(NSString *)kCFProxyTypeKey] isEqualToString:@"kCFProxyTypeNone"]) {
        NSString *hostName = [settings objectForKey:(NSString *)kCFProxyHostNameKey];
        NSString *portNumber = [settings objectForKey:(NSString *)kCFProxyPortNumberKey];
        if (hostName || portNumber) {
            NSLog(@"检测到设备已设置了代理 --> %@:%@", hostName, portNumber);
        } else {
            NSLog(@"检测到设备已设置了代理 --> %@",[settings objectForKey:(NSString *)kCFProxyAutoConfigurationURLKey]);
        }
    }
#endif
}
// 在HTTPHeaderField里返回cookies
- (void)setCookieForRequest:(NSMutableURLRequest *)request {
    NSArray *availableCookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies];
    NSDictionary* headers = [NSHTTPCookie requestHeaderFieldsWithCookies:availableCookies];
    [request setAllHTTPHeaderFields:headers];
}

- (NSMutableURLRequest *)cacheRequestUrl:(NSString *)url method:(NSString *)method params:(NSDictionary *)params {
    NSMutableDictionary *cacheParams = [MCNetwork getRequestBodyWithParams:params URL:[NSURL URLWithString:url] isCache:true];
    [cacheParams removeObjectForKey:@"timestamp"];
    return [self requestWithUrl:url method:method shouldAutoFillBody:false params:cacheParams];
}

- (void)dictionaryWithData:(id)data complete:(void (^)(NSDictionary *object))complete {
    __block NSDictionary *object = data;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if ([data isKindOfClass:[NSData class]]) {
            object = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:nil];
        }
        if ([data isKindOfClass:[NSString class]]) {
            object = [data object];
        }
        object = [object mc_cleanNull];
        dispatch_async(dispatch_get_main_queue(), ^{
            !complete ?: complete(object ?: data);
        });
    });
}

- (void)localCacheToUrl:(NSString *)url params:(NSDictionary *)params complete:(HTTPTaskCompleteHandler)complete {
    NSURLRequest *cacheRequest = [self cacheRequestUrl:url method:@"GET" params:params];
    
    NSCachedURLResponse *cachedResponse = [[NSURLCache sharedURLCache] cachedResponseForRequest:cacheRequest];
    if (cachedResponse != nil && [[cachedResponse data] length] > 0) {
        id object = cachedResponse.data;
        if ([object isKindOfClass:[NSData class]]) {
            object = [NSJSONSerialization JSONObjectWithData:object options:NSJSONReadingMutableLeaves error:nil];
        }
        if ([object isKindOfClass:[NSString class]]) {
            object = [object object];
        }
        
        HTTPResponse *resObj = [[HTTPResponse alloc] init];
        resObj.requestURL = cacheRequest.URL;
        resObj.requestParams = params;
        resObj.payload = object;
        resObj.isCache = YES;
        [self handleResponse:resObj complete:complete];
    }
    else {
        HTTPResponse *resObj = [[HTTPResponse alloc] init];
        resObj.requestURL = cacheRequest.URL;
        resObj.requestParams = params;
        resObj.isCache = YES;
        resObj.error = [NSError errorWithDomain:NSURLErrorDomain
                                           code:NSURLErrorResourceUnavailable
                                       userInfo:@{NSLocalizedDescriptionKey:@"缓存数据不存在"}];
        !complete ?: complete(false, resObj);
    }
}

- (void)handleResponse:(HTTPResponse *)resObj complete:(HTTPTaskCompleteHandler)complete {
    NSDictionary *response = resObj.payload;
    BOOL illegalData = ![response isKindOfClass:[NSDictionary class]];
    // 非法数据MC
    if (illegalData) {
        resObj.payload = nil;
        // resObj.msg = @"服务端返回数据非法";
        resObj.error = [NSError errorWithDomain:NSURLErrorDomain
                                           code:NSURLErrorCannotDecodeContentData
                                       userInfo:@{NSLocalizedDescriptionKey:@"返回的数据格式不正确"}];
        !complete ?: complete(false, resObj);
        return;
    }
    if (response[@"time_point"] && !resObj.isCache) {
        @try {
            double systime = [response[@"time_point"] doubleValue];
            double localTime = [[NSDate date] timeIntervalSince1970] * 1000;
            [userDefaults setObject:@(systime - localTime) forKey:SYSTEM_TIME_DIFF];
            resObj.date = [NSDate ug_dateWithTimestamp:systime];
        }
        @catch (NSException *exception) {}
    }
    
    BOOL success = [response[@"success"] boolValue];
    NSDictionary *responseDataDict = resObj.dataDict;
    resObj.msg = responseDataDict[@"message"];
    if (success) {
        !complete ?: complete(true, resObj);
        /// 每日任务
        if ([resObj.dataDict isKindOfClass:[NSDictionary class]]) {
            if (resObj.dataDict[@"task_message"] && ![resObj.dataDict[@"task_message"] isEqualToString:@"0"]) {
                if (!kStringIsEmpty(resObj.dataDict[@"task_message"])) {
                    [MCToast showMessage:resObj.dataDict[@"task_message"]];
                    if (_loginUser) {
                        [MCLoginUserManager requestServerToUpdateLoginUserInfo];
                    }
                    [[NSNotificationCenter defaultCenter] postNotificationName:Noti_FinishTask object:nil];
                }
            }
        }
    }
    else {
        if (!ENV_RELEASE) {
            [MCBannerAlertView showMessage:resObj.msg];
        }
        int errorCode = [responseDataDict[@"code"] intValue];
        resObj.errorCode = errorCode;
        
        resObj.error = [NSError errorWithDomain:NSURLErrorDomain
                                           code:errorCode
                                       userInfo:@{NSLocalizedDescriptionKey:resObj.msg}];
        if (errorCode == 100007) { // 被蹬出
            [MCLoginUserManager logoutWithCompletion:^{
                // [_applicationContext.navigationController popToRootViewControllerAnimated:true];
            }];
        } else if (errorCode == 200069){ // 被封号
            [_applicationContext.navigationController popToRootViewControllerAnimated:false];
            [_applicationContext.homeMainViewController setPageIndex:0];
            [MCLoginUserManager logoutWithCompletion:nil];
        }
        !complete ?: complete(false, resObj);
        
        NSString *notice = responseDataDict[@"n"];
        if (notice.length && !resObj.isCache) {
            MCAlertView *alertView = [MCAlertView initWithTitle:nil message:notice cancelButtonTitle:@"确定" otherButtonTitles:nil];
            [alertView showWithCompletionBlock:^(NSInteger buttonIndex) {
                
            }];
        }
    }
}

- (void)handleHttpResponseError:(NSError *)error useCache:(BOOL)useCache {
    if (error.code == NSURLErrorCancelled) {
        return;
    }
    switch (error.code) {
        case kCFURLErrorTimedOut: {
            [MCToast showMessage:MCNetworkMessageTimedOut];
        } break;
        case kCFURLErrorNotConnectedToInternet: {
            [MCToast showMessage:MCNetworkMessageNotReachable];
        } break;
        default:
            if (IS_TEST_NET_ENV) {
               [MCBannerAlertView showMessage:error.localizedDescription];
            }
            
            break;
    }
}

- (void)logInfoWithRequest:(NSURLRequest *)request method:(NSString *)method res:(id)res {
    void (^logJWTParams)(NSString *jwtStr) = ^(NSString *jwtStr) {
        NSArray *strs = [jwtStr componentsSeparatedByString:@"."];
        if (strs.count == 3) {
            NSString *paramsStr = strs[1];
            paramsStr = [[paramsStr stringByReplacingOccurrencesOfString:@"-" withString:@"+"]
             stringByReplacingOccurrencesOfString:@"_" withString:@"/"];
            DLOG(@"\n\nBase64Decoded Params: \n%@\n", [NSString stringWithBase64EncodedString:paramsStr]);
        }
    };
    
    if ([request.HTTPMethod isEqualToString:@"GET"]) {
        NSString *getURLString = [request.URL.absoluteString ug_decode];
        DLOG(@"GET request url:  %@", getURLString);
        NSString *paramsString = [getURLString componentsSeparatedByString:@"?"].lastObject;
        logJWTParams(paramsString);
    }
    else {
        DLOG(@"%@ request url:  %@  \npost params:  %@\n",[method uppercaseString],[request.URL.absoluteString ug_decode], request.accessibilityValue);
        NSDictionary *paramsDict = [request.accessibilityValue ug_object];
        if ([paramsDict isKindOfClass:[NSDictionary class]]) {
            NSString *jwtStr = paramsDict[@"data"];
            logJWTParams(jwtStr);
        }
    }
    DLOG(@"%@ responseObject:  %@",[method lowercaseString], res);
}

- (NSURLSessionDataTask *)cacheDataTaskWithRequest:(NSURLRequest *)urlRequest
                                      cacheRequest:(NSURLRequest *)cacheRequest
                                 completionHandler:(void (^)(NSURLResponse *response, id responseObject, NSError *error))completionHandler {
    NSURLSessionDataTask *dataTask =
    [_sessionManager dataTaskWithRequest:urlRequest uploadProgress:nil downloadProgress:nil
                       completionHandler:^(NSURLResponse *response, id responseObject, NSError *error) {
                           if (error) {
                               if (error.code == NSURLErrorNotConnectedToInternet || error.code == NSURLErrorCannotConnectToHost) {
                                   NSCachedURLResponse *cachedResponse = [[NSURLCache sharedURLCache] cachedResponseForRequest:cacheRequest];
                                   if (cachedResponse != nil && [[cachedResponse data] length] > 0) {
                                       NSURLResponse *response = cachedResponse.response;
                                       response.accessibilityValue = @"cache_data";
                                       completionHandler(response, cachedResponse.data, nil);
                                   }
                                   else {
                                       completionHandler(nil, nil, error);
                                   }
                               }
                               else {
                                   completionHandler(nil, responseObject, error);
                               }
                           }
                           else {
                               //store in cache
                               [self dictionaryWithData:responseObject complete:^(NSDictionary *object) {
                                   NSData *data = [[object ug_json] dataUsingEncoding:NSUTF8StringEncoding];
                                   
                                   NSCachedURLResponse *cachedURLResponse = [[NSURLCache sharedURLCache] cachedResponseForRequest:cacheRequest];
                                   cachedURLResponse = [[NSCachedURLResponse alloc] initWithResponse:response data:data userInfo:nil storagePolicy:NSURLCacheStorageAllowed];
                                   [[NSURLCache sharedURLCache] storeCachedResponse:cachedURLResponse forRequest:cacheRequest];
                                   
                                   completionHandler(response, object, error);
                               }];
                           }
                       }];
    return dataTask;
}

- (void)takesTimeWithRequest:(NSURLRequest *)request flag:(NSString *)flag {
    if (!request || !request.accessibilityHint) {
        return;
    }
    NSURL *url = request.URL;
    double beginTime = [request.accessibilityHint doubleValue];
    double localTime = [[NSDate date] timeIntervalSince1970];
    NSLog(@"%@: %@ 耗时：%.3f秒",flag,url.ug_interface, localTime-beginTime);
}

+ (BOOL)isNeedVerifyForUrl:(NSString *)url {
    return true;
}

- (void)downloadWithUrl:(NSString *)url progress:(void(^)(CGFloat))progress completion:(void (^)(NSURL *, NSError *))completion {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    NSURLSessionDownloadTask *task = [_sessionManager downloadTaskWithRequest:request progress:^(NSProgress * _Nonnull downloadProgress) {
        if (progress) {
            CGFloat p = downloadProgress.completedUnitCount*1.f / downloadProgress.totalUnitCount;
            p = (ceilf)(p*100) / 100.f;
            progress(p);
        }
    } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
        NSString *path = [NSCachePath() stringByAppendingPathComponent:response.suggestedFilename];
        NSURL *url = [NSURL fileURLWithPath:path];
        return url;
    } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
        if (completion) {
            completion(filePath, error);
        }
    }];
    [task resume];
}

+ (NSMutableDictionary *)getRequestBodyWithParams:(NSDictionary *)params URL:(NSURL *)URL isCache:(BOOL)isCache {
    NSMutableDictionary *requestBody = params.mutableCopy ?: [NSMutableDictionary dictionary];
    
    UIDevice *currentDevice = [UIDevice currentDevice];
    requestBody[@"device_id"] = currentDevice.uuid;
    requestBody[@"timestamp"] = systime();
    requestBody[@"platform"] = @"0"; // 0:iOS，1:Android
    requestBody[@"app_version_code"] = XcodeVersionCode;
    requestBody[@"app_version_name"] = XcodeAppVersion;
    if ([[_loginUser accessToken] length]) {
        requestBody[@"access_token"] = _loginUser.accessToken;
    }
    
    if (!NetWorkJWTEnabled || isCache) {
        return requestBody;
    }
    // JWT加密
    NSError *error;
    NSString *onlineKey = @"OnlineKeyForSafe";
    NSString *testKey = @"TestKeyForSage";
    NSString *jwtKey = IS_TEST_NET_ENV ? testKey : onlineKey;
    NSString *resultStr = [MCJWT encodeWithPayload:requestBody key:jwtKey error:&error];
    NSDictionary *resultDict = @{ @"data": resultStr };
    if (error) {
        DLOG(@"JWT Error => %@", error.localizedDescription);
    }
    return resultDict.mutableCopy;
}

static inline NSString * systime() {
    double difference = [[userDefaults objectForKey:SYSTEM_TIME_DIFF] doubleValue];
    double localTime = [[NSDate date] timeIntervalSince1970] * 1000;
    NSString *systime = [NSString stringWithFormat:@"%.0f",(localTime+difference)];
    return systime;
}

@end

NSString *const MCNetworkMessageNotReachable = @"网络未连接 请检查网络后重试_(:з」∠)_";
NSString *const MCNetworkMessageTimedOut = @"";
