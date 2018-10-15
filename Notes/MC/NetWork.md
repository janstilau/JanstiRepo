# NetWork

摩擦使用的网络, 是对于 AFN 的二次封装. 其中, 增加了加密信息, 一些默认参数, 以及对于请求的缓存功能.

## HTTPResponse 

@interface HTTPResponse : NSObject
@property (nonatomic, strong) NSDictionary *dataDict;      //!< 返回的data数据, 即 response.payload[@"data"];
@property (nonatomic, assign) BOOL         isCache;        //!< 是否是缓存链接
@property (nonatomic, strong) NSURL        *requestURL;    //!< 请求URL
@property (nonatomic, strong) NSDictionary *requestParams; //!< 请求参数
@property (nonatomic, strong) id           payload;        //!< 响应体（已解密）
@property (nonatomic, strong) NSString     *msg;
@property (nonatomic, strong) NSError      *error;
@property (nonatomic, strong) NSDate       *date;
@property (nonatomic, assign) NSInteger errorCode;
@end
typedef void (^HTTPTaskProgressHandler)(int64_t completedUnitCount, int64_t totalUnitCount);
typedef void (^HTTPTaskCompleteHandler)(BOOL successed, HTTPResponse *response);
这个类主要就是记录数据. 在最终网络请求的回调里面, 传出来的最终的数据就全部封装到这个类里面.
这个类只有一个方法, 功能也仅仅是做一下返回数据的 data 的容错处理.
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


## UGJSONResponseSerializer
这一个类的唯一方法就是下面, 也就是把 AFN 解析完的数据做一个容错处理, 现在看的效果是, 返回的 data 直接为字符串形式, 
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

## MCNetWork

@interface MCNetwork ()
@property (nonatomic, strong) Reachability *reachability;
@property (nonatomic, strong) NSMutableArray <void(^)(NetworkStatus status)> *netChanggeCallbacks; // 网络状态变化注册的回调

@end

@implementation MCNetwork


- (void)setup {
    UGJSONResponseSerializer *responseSerializer = [UGJSONResponseSerializer serializer];
    <!-- The acceptable MIME types for responses. When non-`nil`, responses with a `Content-Type` with MIME types that do not intersect with the set will result in an error during validation. -->
    responseSerializer.acceptableContentTypes = nil; 
    responseSerializer.removesKeysWithNullValues = NO;
    
    NSURL *baseURL = [NSURL URLWithString:INIT_DOMAIN];
    _sessionManager = [[AFHTTPSessionManager alloc] initWithBaseURL:baseURL];
    _sessionManager.responseSerializer = responseSerializer;
    
    // NSURLCache, 做网络缓存的具体类
    NSURLCache *urlCache = [NSURLCache sharedURLCache];
    [urlCache setMemoryCapacity:50 * 1024 * 1024];
    [urlCache setDiskCapacity:200 * 1024 * 1024];
    [NSURLCache setSharedURLCache:urlCache];
    
    // 关于网络变化的处理
    _reachability = [Reachability reachabilityForInternetConnection];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reachabilityChanged:)
                                                 name:kReachabilityChangedNotification
                                               object:nil];
    [_reachability startNotifier];
    <!-- [_sessionManager.reachabilityManager setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        FLOG(@"AFNetworkReachabilityStatus: %@", AFStringFromNetworkReachabilityStatus(status));
        这是原来的设置回调的代码, AFN 的 sessionManager 里面, 其实是自带了网络请求变化的对调. 原来仅仅是简单的打印一下状态的变化, 现在增加了队列, 对回调进行了管理
    }]; -->
}

// 网络状态的处理.
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
        DLOG(@"%@", statusStr);
        [self.netChanggeCallbacks enumerateObjectsUsingBlock:^(void (^ _Nonnull obj)(NetworkStatus), NSUInteger idx, BOOL * _Nonnull stop) {
            obj(status);
        }];
    });
}

- (NetworkStatus)networkStatus {
    return _reachability.currentReachabilityStatus;
}


<!--  具体的网络请求接口 -->

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

<!-- 之前的方法, 仅仅是对于下面的方法的一个封装.  requestHandler 是指对 request 做一次在处理, complete 是对于包装出的 httpResponse 进行处理.-->
- (NSURLSessionDataTask *)requestToUrl:(NSString *)url
                                method:(NSString *)method
                              useCache:(BOOL)useCache
                                params:(NSDictionary *)params
                               request:(HTTPTaskRequestHandler)requestHandler
                              complete:(HTTPTaskCompleteHandler)completeHandler {
    <!--  如果, 网络连接有问题, 直接提示返回. -->
    if (NetWork.networkStatus == NotReachable && !useCache) {
        [MCToast showMessage:MCNetworkMessageNotReachable];
        !completeHandler ?: completeHandler(false, nil);
        return nil;
    }
    <!-- JWT, 一种加密的方式, 简单来说, 私钥由服务器端那边提供,  服务器端在获取到请求之后, 会对签名做一次验证, 如果签名有问题, 则证明是伪造的请求. -->
    if (!NetWorkJWTEnabled) {
        <!-- 如果 JWT not enabled, 那么在 url 中增加 debug 标识, 后面我们也可以看到, 这个宏有多处运用 -->
        url = [url stringByAppendingString:@"?__debug__=1"]; 
    }
    <!-- 获取 httpRequest, 然后添加进行自定义处理, 增加头信息. 具体的操作, 在对应函数中分析. -->
    NSMutableURLRequest *request = [self requestWithUrl:url method:method shouldAutoFillBody:true params:params];
    if (requestHandler) {
        requestHandler(request);
    }
    [self fillHeaderFileds:request];
    
    <!-- 设置 complete 回调 -->
    NSURLSessionDataTask *dataTask = nil;
    void (^completionHandler)(NSURLResponse *, id, NSError *) = ^(NSURLResponse *response, id responseObject, NSError *error) {
        <!-- 打印请求, 相应, 调试用 -->
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
        <!-- 如果是 cache, 那么生成 cacheRequest, 这个 request 里面去掉了 时间戳, 并且不添加默认参数-->
        NSURLRequest *cacheRequest = [self cacheRequestUrl:url method:@"GET" params:params];
        dataTask = [self cacheDataTaskWithRequest:request cacheRequest:cacheRequest completionHandler:completionHandler];
    }
    else {
        <!-- 如果不是 cache, 直接用 afn 生成任务 -->
        dataTask = [_sessionManager dataTaskWithRequest:request uploadProgress:nil downloadProgress:nil completionHandler:completionHandler];
    }
    [dataTask resume];
    return dataTask;
}

<!-- 生成 Request 的相关代码 -->
+ (BOOL)isNeedVerifyForUrl:(NSString *)url {
    return true;
}
<!-- 原来的代码逻辑是, 这个网络请求是不是 -->
<!-- + (BOOL)isNeedVerifyForUrl:(NSString *)url
{
    NSURL *urlObj = [NSURL URLWithString:url];
    if ([urlObj.host hasSuffix:HappyInHostSuffix]) {
        return YES;
    }
    else {
        return [url hasPrefix:BASE_URL_API] || [url hasPrefix:BASE_URL_UPLOAD] || [url hasPrefix:BASE_URL_INIT];
    }
} -->


- (NSMutableURLRequest *)requestWithUrl:(NSString *)url
                                 method:(NSString *)method
                     shouldAutoFillBody:(BOOL)shouldAutoFillBody
                                 params:(NSDictionary *)params {
    <!-- 检测是否设置了代理 -->
    [self detectProxy];
    NSMutableDictionary *requestParams = params.mutableCopy ?: [NSMutableDictionary dictionary];
    NSURL *requestURL = [NSURL URLWithString:url];
    // DLOG(@"%@请求的原始业务参数：%@ ", requestURL.path, [params sortedStr]);
    BOOL needVerify = [[self class] isNeedVerifyForUrl:url];
    <!--  这里, 由于 needVerify 现在固定返回了 true, 所以其实就是 shouldAutoFillBody 决定, 而判断体里面的方法是添加了一些默认参数. 
    现在的代码逻辑是, 如果是 request 就添加, 如果是 cache , 就不添加.-->
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
    <!-- 下面两个是利用系统的accessibility绑定了一些数据到系统定义的对象上. -->
    request.accessibilityValue = [requestParams ug_json]; 
    request.accessibilityHint = [@([[NSDate date] timeIntervalSince1970]) stringValue];
    [request setTimeoutInterval:20];
    <!-- cache 的功能由 app 管理 -->
    [request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
    
    if(needVerify){
        <!-- cookie 这里一直没明白在 app 里面的价值. -->
        [self setCookieForRequest:request];
    }
    return request;
}

<!-- 在业务参数的基础上, 增加了一些默认参数. 包括设备 id, 时间, 平台, 版本号, 以及用户的 token 信息, 并且进行一次加密 -->
+ (NSMutableDictionary *)getRequestBodyWithParams:(NSDictionary *)params URL:(NSURL *)URL isCache:(BOOL)isCache {
    NSMutableDictionary *requestBody = params.mutableCopy ?: [NSMutableDictionary dictionary];
    
    UIDevice *currentDevice = [UIDevice currentDevice];
    requestBody[@"device_id"] = currentDevice.uuid;
    <!-- systime 是为了防止 localTime 和服务器time不一致的情况, 每次网络请求的结果都将一个差值存到偏好设置里面, 在发送网络请求的时候, 把这个差值填回去 -->
    requestBody[@"timestamp"] = systime();
    requestBody[@"platform"] = @"0"; // 0:iOS，1:Android
    <!-- #define XcodeVersionCode  [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"] -->
    requestBody[@"app_version_code"] = XcodeVersionCode;
    if ([[_loginUser accessToken] length]) {
        requestBody[@"access_token"] = _loginUser.accessToken;
    }
    
    if (!NetWorkJWTEnabled || isCache) {
        return requestBody;
    }
    // JWT加密
    <!-- 如果需要 JWT 加密, 则将上面的参数, 统统加密后放到 data 字符串之中. 之前的代码, 统统用的 post, 而对于一些获取操作, 应该用 get, 现在有了加密的措施, get 也没有问题了. 当然, 这种不安全指的是 http 的环境下. -->
    NSError *error;
    NSString *onlineKey = @"Moego&yhmLoB3PJpq&*@#%";
    NSString *testKey = @"Moego&Key&*@#%";
    NSString *jwtKey = IS_TEST_NET_ENV ? testKey : onlineKey;
    NSString *resultStr = [MCJWT encodeWithPayload:requestBody key:jwtKey error:&error];
    NSDictionary *resultDict = @{ @"data": resultStr };
    if (error) {
        DLOG(@"JWT Error => %@", error.localizedDescription);
    }
    return resultDict.mutableCopy;
}
@end

## JST加密
@interface MCJWT : NSObject
+ (NSString *)encodeWithPayload:(NSDictionary *)payload
                            key:(NSString *)key
                          error:(NSError **)error;

+ (NSString *)encodeWithPayload:(NSDictionary *)payload
                            key:(NSString *)key
                      algorithm:(AlgorithmType)algorithm
                       error:(NSError **) error;

+ (NSDictionary *)decodeWithToken:(NSString *)token
                              key:(NSString *)key
                     shouldVerify:(BOOL)verify
                            error:(NSError **)error;
@end

@implementation MCJWT
+ (NSDictionary *)decodeWithToken:(NSString *)token
                              key:(NSString *)key
                     shouldVerify:(BOOL)verify
                            error:(NSError **)error {
    NSArray *segments = [token componentsSeparatedByString:@"."];
    if([segments count] != 3) {
        [MCJWT setErrorWithCode:-1000 reason:@"Not enough or too many segments" error:error];
        return nil;
    }
    // Check key
    if(key == nil || [key length] == 0) {
        [MCJWT setErrorWithCode:-1004 reason:@"Key cannot be nil or empty" error:error];
        return nil;
    }
    
    // All segments should be base64
    NSString *headerSeg = segments[0];
    NSString *payloadSeg = segments[1];
    NSString *signatureSeg = segments[2];
    
    // Decode and parse header and payload JSON
    NSDictionary *header = [NSJSONSerialization JSONObjectWithData:[MCJWT base64DecodeWithString:headerSeg] options:NSJSONReadingMutableLeaves error:error];
    if(header == nil) {
        [MCJWT setErrorWithCode:-1001 reason:[NSString stringWithFormat:@"%@ %@", @"Cannot deserialize header:", [*error localizedFailureReason]] error:error];
        return nil;
    }
    NSDictionary *payload = [NSJSONSerialization JSONObjectWithData:[MCJWT base64DecodeWithString:payloadSeg] options:NSJSONReadingMutableLeaves error:error];
    if(payload == nil) {
        [MCJWT setErrorWithCode:-1001 reason:[NSString stringWithFormat:@"%@ %@", @"Cannot deserialize payload:", [*error localizedFailureReason]] error:error];
        return nil;
    }
    
    if(verify) {
        AlgorithmType algorithmType = [MCAlgorithm getNameWithAlgorithmValue:header[@"alg"]];
        
        // Verify signature. `sign` will return base64 string
        NSString *signinInput = [[NSArray arrayWithObjects: headerSeg, payloadSeg, nil] componentsJoinedByString:@"."];
        if (![MCJWT verifyWithInput:signinInput key:key andAlgorithm:algorithmType signature:signatureSeg]) {
            [MCJWT setErrorWithCode:-1003 reason:@"Decoding failure: Signature verification failed" error:error];
            return nil;
        }
    }
    
    return payload;
}

+ (NSString *)encodeWithPayload:(NSDictionary *)payload
                            key:(NSString *)key
                          error:(NSError **)error {
    // Check key
    if(key == nil || [key length] == 0) {
        <!-- 这里, 应该 *error = [self errorWithCode: reason:] 的形式, 这样代码逻辑清晰, error 本身作为一个传出参数, 要到另外一个方法里面进行赋值. 太复杂-->
        [MCJWT setErrorWithCode:-1004 reason:@"Key cannot be nil or empty" error:error];
        return nil;
    }
    
    NSDictionary *header = @{ @"typ": @"JWT",
                              @"alg": @"HS256" };
    <!-- 增加加密头算法信息. -->
    NSData *jsonHeader = [NSJSONSerialization dataWithJSONObject:header options:0 error:error];
    if(jsonHeader == nil) {
        [MCJWT setErrorWithCode:-1002 reason:[NSString stringWithFormat:@"%@ %@", @"Cannot serialize header:", [*error localizedFailureReason]] error:error];
        return nil;
    }
    <!-- 增加加密算法体信息 -->
    NSData *jsonPayload = [NSJSONSerialization dataWithJSONObject:payload options:0 error:error];
    if(jsonPayload == nil) {
        [MCJWT setErrorWithCode:-1002 reason:[NSString stringWithFormat:@"%@ %@", @"Cannot serialize payload:", [*error localizedFailureReason]] error:error];
        return nil;
    }
    
    NSMutableArray *segments = [[NSMutableArray alloc] initWithCapacity:3];
    [segments addObject:[MCJWT base64EncodeWithBytes:jsonHeader]];
    [segments addObject:[MCJWT base64EncodeWithBytes:jsonPayload]];
    <!-- 将头信息, 体信息和起来然后进行签名. -->
    [segments addObject:[MCJWT signWithInput:[segments componentsJoinedByString:@"."] key:key algorithm:HS256]];
    <!-- 将头信息, 体信息, 签名信息合成一份数据, 用.分割 -->
    return [segments componentsJoinedByString:@"."];
}

+(NSString *) encodeWithPayload:(NSObject *)payload
                            key:(NSString *)key
                      algorithm:(AlgorithmType)algorithm
                       error:(NSError **)error {
    // Check key
    if(key == nil || [key length] == 0) {
        [MCJWT setErrorWithCode:-1004 reason:@"Key cannot be nil or empty" error:error];
        return nil;
    }
    
    NSDictionary *header = @{
                             @"typ": @"JWT",
                             @"alg": [MCAlgorithm getValueWithAlgorithmType:algorithm]
                             };
    
    NSData *jsonHeader = [NSJSONSerialization dataWithJSONObject:header options:0 error:error];
    if(jsonHeader == nil) {
        [MCJWT setErrorWithCode:-1002 reason:[NSString stringWithFormat:@"%@ %@", @"Cannot serialize header:", [*error localizedFailureReason]] error:error];
        return nil;
    }
    NSData *jsonPayload = [NSJSONSerialization dataWithJSONObject:payload options:0 error:error];
    if(jsonPayload == nil) {
        [MCJWT setErrorWithCode:-1002 reason:[NSString stringWithFormat:@"%@ %@", @"Cannot serialize payload:", [*error localizedFailureReason]] error:error];
        return nil;
    }
    
    NSMutableArray *segments = [[NSMutableArray alloc] initWithCapacity:3];
    [segments addObject:[MCJWT base64EncodeWithBytes:jsonHeader]];
    [segments addObject:[MCJWT base64EncodeWithBytes:jsonPayload]];
    [segments addObject:[MCJWT signWithInput:[segments componentsJoinedByString:@"."] key:key algorithm:algorithm]];
    
    return [segments componentsJoinedByString:@"."];
}

<!-- Base64可以将二进制转码成可见字符方便进行http传输，但是base64转码时会生成“+”，“/”，“=”这些被URL进行转码的特殊字符，导致两方面数据不一致。 我们可以在发送前将“+”，“/”，“=”替换成URL不会转码的字符，接收到数据后，再将这些字符替换回去，再进行解码。 -->
+ (NSString *)base64EncodeWithBytes:(NSData *)bytes {
    NSString *base64str = [bytes base64EncodedStringWithOptions:0];
    
    return [[[base64str stringByReplacingOccurrencesOfString:@"+" withString:@"-"]
             stringByReplacingOccurrencesOfString:@"/" withString:@"_"]
            stringByReplacingOccurrencesOfString:@"=" withString:@""];
}

+ (NSData *)base64DecodeWithString:(NSString *)string {
    string = [[string stringByReplacingOccurrencesOfString:@"-" withString:@"+"]
              stringByReplacingOccurrencesOfString:@"_" withString:@"/"];
    
    int size = [string length] % 4;
    NSMutableString *segment = [[NSMutableString alloc] initWithString:string];
    for (int i = 0; i < size; i++) {
        [segment appendString:@"="];
    }
    
    return [[NSData alloc] initWithBase64EncodedString:segment options:0];
}

+ (NSString *)signWithInput:(NSString *)input
                        key:(NSString *)key
                  algorithm:(AlgorithmType)algorithm {
    const char *cKey = [key cStringUsingEncoding:NSASCIIStringEncoding];
    const char *cInput = [input cStringUsingEncoding:NSASCIIStringEncoding];
    NSData *bytes;
    
    unsigned char cHMAC[[MCAlgorithm getDigestLengthWithAlgorithmType:algorithm]];
    CCHmac(kCCHmacAlgSHA256, cKey, strlen(cKey), cInput, strlen(cInput), cHMAC);
    bytes = [[NSData alloc] initWithBytes:cHMAC length:sizeof(cHMAC)];
    
    return [MCJWT base64EncodeWithBytes:bytes];
}

+ (BOOL)verifyWithInput:(NSString *)input
                 key:(NSString *)key
           andAlgorithm:(AlgorithmType)algorithm
           signature:(NSString *)signature {
    return [signature isEqualToString:[MCJWT signWithInput:input key:key algorithm:algorithm]];
}

+ (void)setErrorWithCode:(int)code
                  reason:(NSString *)reason
                   error:(NSError **)error {
    NSString *domain = @"com.himoca";
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    [userInfo setObject:reason forKey:NSLocalizedFailureReasonErrorKey];
    *error = [[NSError alloc] initWithDomain:domain code:code userInfo:userInfo];
}

<!-- cacheDataTaskWithRequest 的作用在于, 请求网络, 注意, 这里还是要请求网络, 如果成功了就讲相应存储起来, 可以看到这里 cacheRequest 并不是真正的网络请求的对象, 只是作为 NSCache 的 key 值的作用. 如果访问不成功, 则通过 cacheRequest 先去寻找缓存数据, 如果有, 则标记这是缓存, 调用回调, 如果没有, 就彻底失败了. -->
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

<!-- localCache 是直接寻找缓存数据, 没有网络请求. -->
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

<!-- 统一的处理响应数据 -->
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
    <!-- 存储和服务器的时间戳差异 -->
    if (response[@"time_point"] && !resObj.isCache) {
        @try {
            double systime = [response[@"time_point"] doubleValue];
            double localTime = [[NSDate date] timeIntervalSince1970] * 1000;
            [userDefaults setObject:@(systime - localTime) forKey:SYSTEM_TIME_DIFF];
            resObj.date = [NSDate ug_dateWithTimestamp:systime];
        }
        @catch (NSException *exception) {}
    }
    <!--  -->
    BOOL success = [response[@"success"] boolValue];
    NSDictionary *responseDataDict = resObj.dataDict;
    resObj.msg = responseDataDict[@"message"];
    if (success) {
        !complete ?: complete(true, resObj);
        /// 每日任务
        <!-- 如果是每日任务完成, 弹框提示并且更新下用户信息. -->
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
        // 被蹬出
        if (errorCode == 100007) {
            [MCLoginUserManager logoutWithCompletion:^{
                // [_applicationContext.navigationController popToRootViewControllerAnimated:true];
            }];
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
@end
